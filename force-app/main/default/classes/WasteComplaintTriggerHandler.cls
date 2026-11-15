/**
 * @description Trigger Handler for Waste_Complaint__c implementing full lifecycle logic,
 * recursion protection, SLA orchestration, team assignments, and notification dispatch.
 */
public with sharing class WasteComplaintTriggerHandler {
    
    // Recursion prevention controls
    public static Boolean isTriggerExecuting = false;

    public void beforeInsert(List<Waste_Complaint__c> newComplaints) {
        for (Waste_Complaint__c wc : newComplaints) {
            if (String.isBlank(wc.Status__c)) {
                wc.Status__c = 'New';
            }
            if (wc.Reported_Date__c == null) {
                wc.Reported_Date__c = DateTime.now();
            }
        }

        // Apply SLA, Priority calculation, and auto-escalation
        SLAService.applySLAAndPriority(newComplaints);

        // Detect and annotate duplicates
        WasteComplaintDuplicateService.tagDuplicateComplaints(newComplaints);

        // Auto-assign teams based on location and capacity
        WasteAssignmentService.autoAssignComplaints(newComplaints);
    }

    public void afterInsert(List<Waste_Complaint__c> newComplaints, Map<Id, Waste_Complaint__c> newMap) {
        Set<Id> affectedTeamIds = new Set<Id>();
        List<Waste_Complaint__c> criticalAlerts = new List<Waste_Complaint__c>();

        for (Waste_Complaint__c wc : newComplaints) {
            if (wc.Assigned_Team__c != null) {
                affectedTeamIds.add(wc.Assigned_Team__c);
            }
            if (wc.Severity__c == 'Critical' || wc.Is_Escalated__c == true) {
                criticalAlerts.add(wc);
            }
        }

        // Update team workload metrics
        if (!affectedTeamIds.isEmpty()) {
            WasteAssignmentService.updateTeamWorkloads(affectedTeamIds);
        }

        // Grant Apex-managed record sharing to assigned team leader and worker
        WasteComplaintSharingService.grantSharingOnInsert(newComplaints);

        // Notify resident of submission
        NotificationService.notifyResidentStatusChange(newComplaints, 'Submitted');

        // Alert administrators if critical
        if (!criticalAlerts.isEmpty()) {
            NotificationService.notifyAdmins(criticalAlerts, 'Critical Waste Complaint Registered');
        }
    }

    public void beforeUpdate(List<Waste_Complaint__c> newComplaints, Map<Id, Waste_Complaint__c> oldMap) {
        List<Waste_Complaint__c> severityChanged = new List<Waste_Complaint__c>();

        for (Waste_Complaint__c wc : newComplaints) {
            Waste_Complaint__c oldWc = oldMap.get(wc.Id);

            // Severity changed -> recalculate SLA and priority
            if (wc.Severity__c != oldWc.Severity__c) {
                severityChanged.add(wc);
            }

            // Resolution logic and validations
            if (wc.Status__c == 'Resolved' && oldWc.Status__c != 'Resolved') {
                if (String.isBlank(wc.Resolution_Notes__c)) {
                    wc.Resolution_Notes__c.addError('Resolution notes are required when marking a complaint as Resolved.');
                }
                if (wc.Resolution_Date__c == null) {
                    wc.Resolution_Date__c = DateTime.now();
                }
            }

            // Status reopened logic
            if (wc.Status__c == 'Reopened' && oldWc.Status__c != 'Reopened') {
                wc.Resolution_Date__c = null;
            }
        }

        if (!severityChanged.isEmpty()) {
            SLAService.applySLAAndPriority(severityChanged);
        }
    }

    public void afterUpdate(List<Waste_Complaint__c> newComplaints, Map<Id, Waste_Complaint__c> oldMap) {
        Set<Id> affectedTeamIds = new Set<Id>();
        List<Waste_Complaint__c> statusChangedList = new List<Waste_Complaint__c>();
        List<Waste_Complaint__c> newlyEscalated = new List<Waste_Complaint__c>();

        for (Waste_Complaint__c wc : newComplaints) {
            Waste_Complaint__c oldWc = oldMap.get(wc.Id);

            // Workload shifts on team reassignment or status changes
            if (wc.Assigned_Team__c != oldWc.Assigned_Team__c || wc.Status__c != oldWc.Status__c) {
                if (wc.Assigned_Team__c != null) {
                    affectedTeamIds.add(wc.Assigned_Team__c);
                }
                if (oldWc.Assigned_Team__c != null) {
                    affectedTeamIds.add(oldWc.Assigned_Team__c);
                }
            }

            // Status transitions trigger resident notifications
            if (wc.Status__c != oldWc.Status__c) {
                statusChangedList.add(wc);
            }

            // Escalation events
            if (wc.Is_Escalated__c == true && oldWc.Is_Escalated__c == false) {
                newlyEscalated.add(wc);
            }
        }

        if (!affectedTeamIds.isEmpty()) {
            WasteAssignmentService.updateTeamWorkloads(affectedTeamIds);
        }

        // Synchronize Apex-managed record sharing on assignment updates
        WasteComplaintSharingService.updateSharingOnUpdate(newComplaints, oldMap);

        if (!statusChangedList.isEmpty()) {
            for (Waste_Complaint__c sc : statusChangedList) {
                NotificationService.notifyResidentStatusChange(new List<Waste_Complaint__c>{ sc }, sc.Status__c);
            }
        }

        if (!newlyEscalated.isEmpty()) {
            NotificationService.notifyAdmins(newlyEscalated, 'Complaint Escalated');
        }
    }

    public void afterDelete(List<Waste_Complaint__c> oldComplaints) {
        Set<Id> affectedTeamIds = new Set<Id>();
        for (Waste_Complaint__c wc : oldComplaints) {
            if (wc.Assigned_Team__c != null) {
                affectedTeamIds.add(wc.Assigned_Team__c);
            }
        }
        if (!affectedTeamIds.isEmpty()) {
            WasteAssignmentService.updateTeamWorkloads(affectedTeamIds);
        }
    }

    public void afterUndelete(List<Waste_Complaint__c> newComplaints) {
        Set<Id> affectedTeamIds = new Set<Id>();
        for (Waste_Complaint__c wc : newComplaints) {
            if (wc.Assigned_Team__c != null) {
                affectedTeamIds.add(wc.Assigned_Team__c);
            }
        }
        if (!affectedTeamIds.isEmpty()) {
            WasteAssignmentService.updateTeamWorkloads(affectedTeamIds);
        }
    }
}
