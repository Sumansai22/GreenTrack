/**
 * @description Bulkified Apex sharing service for Waste_Complaint__c.
 * Manages manual sharing (Waste_Complaint__Share) granting Read/Write (AccessLevel = 'Edit')
 * access to:
 *  1. Salesforce user linked to the assigned Collection Team (Team_Leader_User__c)
 *  2. Salesforce user linked to the assigned Cleaning Worker (Worker_User__c)
 * Safely removes obsolete shares upon assignment changes without deleting unrelated manual shares,
 * avoids duplicate shares, handles null assignments, and supports 200 records per transaction.
 */
public without sharing class WasteComplaintSharingService {

    public static final String ACCESS_LEVEL_EDIT = 'Edit';
    public static final String ROW_CAUSE_MANUAL = 'Manual';

    /**
     * @description Grants manual share records for newly inserted complaints with team or worker assignments.
     * @param newComplaints List of newly inserted Waste_Complaint__c records
     */
    public static void grantSharingOnInsert(List<Waste_Complaint__c> newComplaints) {
        if (newComplaints == null || newComplaints.isEmpty()) {
            return;
        }

        List<Waste_Complaint__c> complaintsWithAssignments = new List<Waste_Complaint__c>();
        for (Waste_Complaint__c wc : newComplaints) {
            if (wc.Assigned_Team__c != null || wc.Assigned_Worker__c != null) {
                complaintsWithAssignments.add(wc);
            }
        }

        if (!complaintsWithAssignments.isEmpty()) {
            syncSharing(complaintsWithAssignments, null);
        }
    }

    /**
     * @description Handles sharing updates when complaints are updated with new team/worker assignments.
     * Removes obsolete manual shares without touching unrelated shares.
     * @param newComplaints List of updated Waste_Complaint__c records
     * @param oldMap Map of prior Waste_Complaint__c states
     */
    public static void updateSharingOnUpdate(List<Waste_Complaint__c> newComplaints, Map<Id, Waste_Complaint__c> oldMap) {
        if (newComplaints == null || newComplaints.isEmpty() || oldMap == null) {
            return;
        }

        List<Waste_Complaint__c> assignmentChangedComplaints = new List<Waste_Complaint__c>();
        for (Waste_Complaint__c wc : newComplaints) {
            Waste_Complaint__c oldWc = oldMap.get(wc.Id);
            if (oldWc != null && (wc.Assigned_Team__c != oldWc.Assigned_Team__c || wc.Assigned_Worker__c != oldWc.Assigned_Worker__c)) {
                assignmentChangedComplaints.add(wc);
            }
        }

        if (!assignmentChangedComplaints.isEmpty()) {
            syncSharing(assignmentChangedComplaints, oldMap);
        }
    }

    /**
     * @description Core bulkified sharing synchronization engine.
     * Computes required active shares and obsolete shares, avoiding duplicates and preserving unrelated shares.
     */
    private static void syncSharing(List<Waste_Complaint__c> complaints, Map<Id, Waste_Complaint__c> oldMap) {
        Set<Id> allTeamIds = new Set<Id>();
        Set<Id> allWorkerIds = new Set<Id>();

        for (Waste_Complaint__c wc : complaints) {
            if (wc.Assigned_Team__c != null) {
                allTeamIds.add(wc.Assigned_Team__c);
            }
            if (wc.Assigned_Worker__c != null) {
                allWorkerIds.add(wc.Assigned_Worker__c);
            }
            if (oldMap != null) {
                Waste_Complaint__c oldWc = oldMap.get(wc.Id);
                if (oldWc != null) {
                    if (oldWc.Assigned_Team__c != null) {
                        allTeamIds.add(oldWc.Assigned_Team__c);
                    }
                    if (oldWc.Assigned_Worker__c != null) {
                        allWorkerIds.add(oldWc.Assigned_Worker__c);
                    }
                }
            }
        }

        Map<Id, Id> teamToLeaderUserMap = new Map<Id, Id>();
        if (!allTeamIds.isEmpty()) {
            for (Collection_Team__c team : [
                SELECT Id, Team_Leader_User__c
                FROM Collection_Team__c
                WHERE Id IN :allTeamIds AND Team_Leader_User__c != null
            ]) {
                teamToLeaderUserMap.put(team.Id, team.Team_Leader_User__c);
            }
        }

        Map<Id, Id> workerToUserMap = new Map<Id, Id>();
        if (!allWorkerIds.isEmpty()) {
            for (Cleaning_Worker__c worker : [
                SELECT Id, Worker_User__c
                FROM Cleaning_Worker__c
                WHERE Id IN :allWorkerIds AND Worker_User__c != null
            ]) {
                workerToUserMap.put(worker.Id, worker.Worker_User__c);
            }
        }

        Map<Id, Set<Id>> complaintToObsoleteUsersMap = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> complaintToActiveUsersMap = new Map<Id, Set<Id>>();
        Set<Id> allTargetUserIds = new Set<Id>();
        Set<Id> complaintIds = new Set<Id>();

        for (Waste_Complaint__c wc : complaints) {
            complaintIds.add(wc.Id);
            Set<Id> activeUsersForThisComplaint = new Set<Id>();

            // Determine active assigned users (exclude record owner as owner already has full access)
            if (wc.Assigned_Team__c != null && teamToLeaderUserMap.containsKey(wc.Assigned_Team__c)) {
                Id leaderUserId = teamToLeaderUserMap.get(wc.Assigned_Team__c);
                if (leaderUserId != null && leaderUserId != wc.OwnerId) {
                    activeUsersForThisComplaint.add(leaderUserId);
                }
            }
            if (wc.Assigned_Worker__c != null && workerToUserMap.containsKey(wc.Assigned_Worker__c)) {
                Id workerUserId = workerToUserMap.get(wc.Assigned_Worker__c);
                if (workerUserId != null && workerUserId != wc.OwnerId) {
                    activeUsersForThisComplaint.add(workerUserId);
                }
            }

            complaintToActiveUsersMap.put(wc.Id, activeUsersForThisComplaint);
            allTargetUserIds.addAll(activeUsersForThisComplaint);

            // Calculate obsolete users on update without affecting unrelated manual shares
            if (oldMap != null) {
                Waste_Complaint__c oldWc = oldMap.get(wc.Id);
                if (oldWc != null) {
                    Set<Id> obsoleteUsersForThisComplaint = new Set<Id>();

                    if (oldWc.Assigned_Team__c != null && teamToLeaderUserMap.containsKey(oldWc.Assigned_Team__c)) {
                        Id oldLeaderUserId = teamToLeaderUserMap.get(oldWc.Assigned_Team__c);
                        if (oldLeaderUserId != null && !activeUsersForThisComplaint.contains(oldLeaderUserId)) {
                            obsoleteUsersForThisComplaint.add(oldLeaderUserId);
                        }
                    }
                    if (oldWc.Assigned_Worker__c != null && workerToUserMap.containsKey(oldWc.Assigned_Worker__c)) {
                        Id oldWorkerUserId = workerToUserMap.get(oldWc.Assigned_Worker__c);
                        if (oldWorkerUserId != null && !activeUsersForThisComplaint.contains(oldWorkerUserId)) {
                            obsoleteUsersForThisComplaint.add(oldWorkerUserId);
                        }
                    }

                    if (!obsoleteUsersForThisComplaint.isEmpty()) {
                        complaintToObsoleteUsersMap.put(wc.Id, obsoleteUsersForThisComplaint);
                    }
                }
            }
        }

        // 1. Delete obsolete shares without touching unrelated manual shares
        List<Waste_Complaint__Share> sharesToDelete = new List<Waste_Complaint__Share>();
        if (!complaintToObsoleteUsersMap.isEmpty()) {
            for (Waste_Complaint__Share existingShare : [
                SELECT Id, ParentId, UserOrGroupId
                FROM Waste_Complaint__Share
                WHERE ParentId IN :complaintToObsoleteUsersMap.keySet()
                  AND RowCause = :ROW_CAUSE_MANUAL
            ]) {
                Set<Id> obsoleteUsers = complaintToObsoleteUsersMap.get(existingShare.ParentId);
                if (obsoleteUsers != null && obsoleteUsers.contains(existingShare.UserOrGroupId)) {
                    sharesToDelete.add(existingShare);
                }
            }
        }

        if (!sharesToDelete.isEmpty()) {
            delete sharesToDelete;
        }

        // 2. Query existing manual shares for target users to prevent duplicates or upgrade Read to Edit
        Set<String> existingShareKeys = new Set<String>();
        List<Waste_Complaint__Share> sharesToUpdate = new List<Waste_Complaint__Share>();

        if (!complaintIds.isEmpty() && !allTargetUserIds.isEmpty()) {
            for (Waste_Complaint__Share existingShare : [
                SELECT Id, ParentId, UserOrGroupId, AccessLevel
                FROM Waste_Complaint__Share
                WHERE ParentId IN :complaintIds
                  AND UserOrGroupId IN :allTargetUserIds
                  AND RowCause = :ROW_CAUSE_MANUAL
            ]) {
                String shareKey = existingShare.ParentId + '_' + existingShare.UserOrGroupId;
                existingShareKeys.add(shareKey);
                if (existingShare.AccessLevel != ACCESS_LEVEL_EDIT) {
                    existingShare.AccessLevel = ACCESS_LEVEL_EDIT;
                    sharesToUpdate.add(existingShare);
                }
            }
        }

        if (!sharesToUpdate.isEmpty()) {
            update sharesToUpdate;
        }

        // 3. Create new shares for active target users avoiding duplicates
        List<Waste_Complaint__Share> sharesToInsert = new List<Waste_Complaint__Share>();
        Set<String> pendingShareKeys = new Set<String>();

        for (Id complaintId : complaintToActiveUsersMap.keySet()) {
            Set<Id> activeUsers = complaintToActiveUsersMap.get(complaintId);
            for (Id userId : activeUsers) {
                String shareKey = complaintId + '_' + userId;
                if (!existingShareKeys.contains(shareKey) && !pendingShareKeys.contains(shareKey)) {
                    sharesToInsert.add(new Waste_Complaint__Share(
                        ParentId = complaintId,
                        UserOrGroupId = userId,
                        AccessLevel = ACCESS_LEVEL_EDIT,
                        RowCause = Schema.Waste_Complaint__Share.RowCause.Manual
                    ));
                    pendingShareKeys.add(shareKey);
                }
            }
        }

        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
        }
    }
}
