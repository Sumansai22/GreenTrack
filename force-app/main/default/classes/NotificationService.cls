/**
 * @description Service class responsible for resident and administrator notifications.
 * Handles in-app alerts, logging, and status notification dispatch.
 */
public with sharing class NotificationService {
    
    // Cache to prevent duplicate notifications during a single transaction
    private static Set<String> processedNotificationKeys = new Set<String>();

    /**
     * @description Notify resident upon complaint status changes
     * @param complaints List of Waste_Complaint__c records
     * @param eventType Description of the event (Submitted, Assigned, In Progress, Resolved, Rejected)
     */
    public static void notifyResidentStatusChange(List<Waste_Complaint__c> complaints, String eventType) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        List<Task> notificationLogs = new List<Task>();

        for (Waste_Complaint__c wc : complaints) {
            if (String.isBlank(wc.Resident_Email__c) && String.isBlank(wc.Resident_Phone__c)) {
                continue;
            }

            String dedupeKey = wc.Id + '_' + eventType + '_' + String.valueOf(System.today());
            if (processedNotificationKeys.contains(dedupeKey)) {
                continue;
            }
            processedNotificationKeys.add(dedupeKey);

            String subject = 'GreenTrack Update: Complaint ' + (wc.Name != null ? wc.Name : 'Record') + ' is ' + eventType;
            String message = 'Dear Resident,\n\nYour waste complaint "' + wc.Complaint_Title__c + 
                             '" has been updated to status: ' + eventType + '.\n' +
                             'Area: ' + (wc.Area__c != null ? wc.Area__c : 'N/A') + '\n' +
                             'Reported on: ' + (wc.Reported_Date__c != null ? wc.Reported_Date__c.format() : 'Recent') + '\n';

            if (eventType == 'Resolved' && String.isNotBlank(wc.Resolution_Notes__c)) {
                message += 'Resolution Notes: ' + wc.Resolution_Notes__c + '\n';
            }

            message += '\nThank you for contributing to a cleaner community!\nGreenTrack Municipal Operations';

            // Log resident notification record as an interaction Task
            if (wc.Id != null) {
                Task logTask = new Task();
                logTask.WhatId = wc.Id;
                logTask.Subject = subject;
                logTask.Description = message;
                logTask.Status = 'Completed';
                logTask.Priority = 'Normal';
                logTask.ActivityDate = Date.today();
                notificationLogs.add(logTask);
            }
        }

        if (!notificationLogs.isEmpty() && Schema.sObjectType.Task.isCreateable()) {
            try {
                insert notificationLogs;
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Failed to log notification tasks: ' + ex.getMessage());
            }
        }
    }

    /**
     * @description Notify municipal administrators about critical complaints, SLA breaches, or assignment gaps
     * @param complaints List of Waste_Complaint__c records requiring attention
     * @param alertReason Reason for administrator alert (e.g. 'Critical Complaint Logged', 'SLA Overdue', 'No Available Team')
     */
    public static void notifyAdmins(List<Waste_Complaint__c> complaints, String alertReason) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        List<Task> adminAlerts = new List<Task>();

        for (Waste_Complaint__c wc : complaints) {
            String dedupeKey = 'ADMIN_' + wc.Id + '_' + alertReason;
            if (processedNotificationKeys.contains(dedupeKey)) {
                continue;
            }
            processedNotificationKeys.add(dedupeKey);

            String subject = 'ADMIN ALERT: [' + alertReason + '] - ' + (wc.Name != null ? wc.Name : 'Complaint');
            String description = 'Urgent Municipal Action Required:\n\n' +
                                 'Reason: ' + alertReason + '\n' +
                                 'Title: ' + wc.Complaint_Title__c + '\n' +
                                 'Severity: ' + wc.Severity__c + '\n' +
                                 'Area: ' + wc.Area__c + '\n' +
                                 'Reported Date: ' + wc.Reported_Date__c + '\n' +
                                 'SLA Deadline: ' + wc.SLA_Deadline__c;

            if (wc.Id != null) {
                Task alertTask = new Task();
                alertTask.WhatId = wc.Id;
                alertTask.Subject = subject;
                alertTask.Description = description;
                alertTask.Priority = 'High';
                alertTask.Status = 'Not Started';
                alertTask.ActivityDate = Date.today();
                adminAlerts.add(alertTask);
            }
        }

        if (!adminAlerts.isEmpty() && Schema.sObjectType.Task.isCreateable()) {
            try {
                insert adminAlerts;
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Failed to insert admin alerts: ' + ex.getMessage());
            }
        }
    }
}
