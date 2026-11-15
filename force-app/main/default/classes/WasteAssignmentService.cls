/**
 * @description Intelligent dispatch and workload management service for Collection Teams
 * and Cleaning Workers.
 */
public with sharing class WasteAssignmentService {
    
    /**
     * @description Automatically matches complaints to available teams based on Area and current workload
     * @param complaints List of incoming Waste_Complaint__c records
     */
    public static void autoAssignComplaints(List<Waste_Complaint__c> complaints) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        Set<String> areaSet = new Set<String>();
        List<Waste_Complaint__c> needsAssignment = new List<Waste_Complaint__c>();

        for (Waste_Complaint__c wc : complaints) {
            // Only auto-assign if team is not explicitly provided
            if (wc.Assigned_Team__c == null) {
                needsAssignment.add(wc);
                if (String.isNotBlank(wc.Area__c)) {
                    areaSet.add(wc.Area__c.trim());
                }
            }
        }

        if (needsAssignment.isEmpty()) {
            return;
        }

        // Fetch active teams matching area or all active available teams
        List<Collection_Team__c> allActiveTeams = [
            SELECT Id, Name, Assigned_Area__c, Availability_Status__c, Active_Status__c, Total_Assigned_Complaints__c
            FROM Collection_Team__c
            WHERE Active_Status__c = true
              AND Availability_Status__c IN ('Available', 'Busy')
            ORDER BY Total_Assigned_Complaints__c ASC
        ];

        Map<String, List<Collection_Team__c>> areaTeamMap = new Map<String, List<Collection_Team__c>>();
        List<Collection_Team__c> generalTeams = new List<Collection_Team__c>();

        for (Collection_Team__c team : allActiveTeams) {
            if (String.isNotBlank(team.Assigned_Area__c)) {
                String key = team.Assigned_Area__c.trim().toLowerCase();
                if (!areaTeamMap.containsKey(key)) {
                    areaTeamMap.put(key, new List<Collection_Team__c>());
                }
                areaTeamMap.get(key).add(team);
            }
            generalTeams.add(team);
        }

        List<Waste_Complaint__c> unassignedComplaints = new List<Waste_Complaint__c>();

        for (Waste_Complaint__c wc : needsAssignment) {
            String areaKey = (wc.Area__c != null) ? wc.Area__c.trim().toLowerCase() : '';
            Collection_Team__c selectedTeam = null;

            if (areaTeamMap.containsKey(areaKey) && !areaTeamMap.get(areaKey).isEmpty()) {
                selectedTeam = areaTeamMap.get(areaKey)[0];
            } else if (!generalTeams.isEmpty()) {
                // Fallback to least loaded active team
                selectedTeam = generalTeams[0];
            }

            if (selectedTeam != null) {
                wc.Assigned_Team__c = selectedTeam.Id;
                if (wc.Status__c == 'New' || wc.Status__c == 'Submitted') {
                    wc.Status__c = 'Assigned';
                }
                // Locally increment to balance bulk assignments
                Decimal currentTotal = selectedTeam.Total_Assigned_Complaints__c != null ? selectedTeam.Total_Assigned_Complaints__c : 0;
                selectedTeam.Total_Assigned_Complaints__c = currentTotal + 1;
            } else {
                unassignedComplaints.add(wc);
            }
        }

        if (!unassignedComplaints.isEmpty()) {
            NotificationService.notifyAdmins(unassignedComplaints, 'No Available Collection Team');
        }
    }

    /**
     * @description Recalculates and updates Total_Assigned_Complaints__c for teams
     * @param teamIds Set of Collection_Team__c IDs
     */
    public static void updateTeamWorkloads(Set<Id> teamIds) {
        if (teamIds == null || teamIds.isEmpty()) {
            return;
        }

        // Aggregate open complaints per team
        Map<Id, Integer> workloadMap = new Map<Id, Integer>();
        for (Id tId : teamIds) {
            workloadMap.put(tId, 0);
        }

        for (AggregateResult ar : [
            SELECT Assigned_Team__c, COUNT(Id) cnt
            FROM Waste_Complaint__c
            WHERE Assigned_Team__c IN :teamIds
              AND Status__c NOT IN ('Resolved', 'Rejected')
            GROUP BY Assigned_Team__c
        ]) {
            Id tId = (Id)ar.get('Assigned_Team__c');
            Integer count = (Integer)ar.get('cnt');
            workloadMap.put(tId, count);
        }

        List<Collection_Team__c> teamsToUpdate = new List<Collection_Team__c>();
        for (Id tId : teamIds) {
            teamsToUpdate.add(new Collection_Team__c(
                Id = tId,
                Total_Assigned_Complaints__c = workloadMap.get(tId)
            ));
        }

        if (!teamsToUpdate.isEmpty()) {
            update teamsToUpdate;
        }
    }

    /**
     * @description Allows LWC administrative UI to assign complaint to team and worker
     */
    @AuraEnabled
    public static void assignComplaintManually(Id complaintId, Id teamId, Id workerId) {
        if (complaintId == null || teamId == null) {
            throw new AuraHandledException('Complaint ID and Team ID are required.');
        }

        Waste_Complaint__c wc = [
            SELECT Id, Name, Status__c, Assigned_Team__c, Assigned_Worker__c, Resident_Email__c, Complaint_Title__c, Area__c, Reported_Date__c, Resolution_Notes__c
            FROM Waste_Complaint__c
            WHERE Id = :complaintId
            LIMIT 1
        ];

        wc.Assigned_Team__c = teamId;
        if (workerId != null) {
            wc.Assigned_Worker__c = workerId;
        }
        if (wc.Status__c == 'New' || wc.Status__c == 'Submitted') {
            wc.Status__c = 'Assigned';
        }

        update wc;
        updateTeamWorkloads(new Set<Id>{ teamId });
        NotificationService.notifyResidentStatusChange(new List<Waste_Complaint__c>{ wc }, 'Assigned');
    }

    /**
     * @description Fetches all available teams for LWC dropdowns, optionally filtered by area
     */
    @AuraEnabled(cacheable=true)
    public static List<Collection_Team__c> getAvailableTeams(String area) {
        if (String.isNotBlank(area)) {
            String sanitizedArea = area.trim();
            List<Collection_Team__c> areaMatched = [
                SELECT Id, Name, Team_Code__c, Team_Leader__c, Contact_Number__c, Assigned_Area__c, Availability_Status__c, Total_Assigned_Complaints__c
                FROM Collection_Team__c
                WHERE Active_Status__c = true
                  AND Assigned_Area__c = :sanitizedArea
                ORDER BY Total_Assigned_Complaints__c ASC
            ];
            if (!areaMatched.isEmpty()) {
                return areaMatched;
            }
        }
        return [
            SELECT Id, Name, Team_Code__c, Team_Leader__c, Contact_Number__c, Assigned_Area__c, Availability_Status__c, Total_Assigned_Complaints__c
            FROM Collection_Team__c
            WHERE Active_Status__c = true
            ORDER BY Total_Assigned_Complaints__c ASC
        ];
    }

    /**
     * @description Fetches workers associated with a team for LWC dropdowns
     */
    @AuraEnabled(cacheable=true)
    public static List<Cleaning_Worker__c> getWorkersByTeam(Id teamId) {
        if (teamId == null) {
            return [
                SELECT Id, Name, Employee_ID__c, Contact_Number__c, Assigned_Area__c, Availability_Status__c, Assigned_Team__c, Assigned_Team__r.Name
                FROM Cleaning_Worker__c
                WHERE Active_Status__c = true
                ORDER BY Name ASC
            ];
        }
        return [
            SELECT Id, Name, Employee_ID__c, Contact_Number__c, Assigned_Area__c, Availability_Status__c, Assigned_Team__c, Assigned_Team__r.Name
            FROM Cleaning_Worker__c
            WHERE Assigned_Team__c = :teamId
              AND Active_Status__c = true
            ORDER BY Name ASC
        ];
    }
}
