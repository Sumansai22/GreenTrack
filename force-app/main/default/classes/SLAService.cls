/**
 * @description Service class managing SLA target calculations, priority mapping,
 * and escalation management using GreenTrack_SLA_Setting__mdt.
 */
public with sharing class SLAService {
    
    // Default fallback SLA hours in case metadata is not yet populated
    private static final Map<String, Integer> DEFAULT_SLA_HOURS = new Map<String, Integer>{
        'Critical' => 6,
        'High'     => 24,
        'Medium'   => 48,
        'Low'      => 72
    };

    /**
     * @description Cached SLA configuration settings from Custom Metadata
     */
    private static Map<String, GreenTrack_SLA_Setting__mdt> slaSettingsMap;

    public static Map<String, GreenTrack_SLA_Setting__mdt> getSLASettings() {
        if (slaSettingsMap == null) {
            slaSettingsMap = new Map<String, GreenTrack_SLA_Setting__mdt>();
            try {
                List<GreenTrack_SLA_Setting__mdt> records = [
                    SELECT MasterLabel, DeveloperName, Target_Severity__c, SLA_Hours__c, Auto_Escalate__c
                    FROM GreenTrack_SLA_Setting__mdt
                ];
                for (GreenTrack_SLA_Setting__mdt s : records) {
                    if (String.isNotBlank(s.Target_Severity__c)) {
                        slaSettingsMap.put(s.Target_Severity__c.toLowerCase(), s);
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Unable to query GreenTrack_SLA_Setting__mdt: ' + ex.getMessage());
            }
        }
        return slaSettingsMap;
    }

    /**
     * @description Applies priority, SLA deadline, and auto-escalation based on Severity
     * @param complaints List of Waste_Complaint__c records
     */
    public static void applySLAAndPriority(List<Waste_Complaint__c> complaints) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        Map<String, GreenTrack_SLA_Setting__mdt> settings = getSLASettings();

        for (Waste_Complaint__c wc : complaints) {
            String sev = wc.Severity__c;
            if (String.isBlank(sev)) {
                sev = 'Medium';
                wc.Severity__c = 'Medium';
            }

            // Map Priority
            if (sev.equalsIgnoreCase('Critical')) {
                wc.Priority__c = 'Urgent';
            } else if (sev.equalsIgnoreCase('High')) {
                wc.Priority__c = 'High';
            } else if (sev.equalsIgnoreCase('Low')) {
                wc.Priority__c = 'Low';
            } else {
                wc.Priority__c = 'Medium';
            }

            // Calculate SLA Hours
            Integer slaHours = DEFAULT_SLA_HOURS.get(sev);
            Boolean shouldAutoEscalate = false;

            if (settings.containsKey(sev.toLowerCase())) {
                GreenTrack_SLA_Setting__mdt conf = settings.get(sev.toLowerCase());
                if (conf.SLA_Hours__c != null) {
                    slaHours = Integer.valueOf(conf.SLA_Hours__c);
                }
                if (conf.Auto_Escalate__c == true) {
                    shouldAutoEscalate = true;
                }
            }

            if (slaHours == null) {
                slaHours = 48;
            }

            // Set Reported Date if not present
            if (wc.Reported_Date__c == null) {
                wc.Reported_Date__c = DateTime.now();
            }

            // Calculate SLA Deadline
            wc.SLA_Deadline__c = wc.Reported_Date__c.addHours(slaHours);

            // Escalate critical complaints
            if (sev.equalsIgnoreCase('Critical') || shouldAutoEscalate) {
                wc.Is_Escalated__c = true;
            }
        }
    }

    /**
     * @description Checks active complaints against current time and escalates overdue records
     * @return List of escalated complaints
     */
    public static List<Waste_Complaint__c> checkAndEscalateBreachedComplaints() {
        List<Waste_Complaint__c> overdueComplaints = [
            SELECT Id, Name, Complaint_Title__c, Severity__c, Status__c, Area__c,
                   Reported_Date__c, SLA_Deadline__c, Is_Escalated__c, Resident_Email__c
            FROM Waste_Complaint__c
            WHERE Status__c NOT IN ('Resolved', 'Rejected')
              AND SLA_Deadline__c < :DateTime.now()
              AND Is_Escalated__c = false
            LIMIT 200
        ];

        if (!overdueComplaints.isEmpty()) {
            for (Waste_Complaint__c wc : overdueComplaints) {
                wc.Is_Escalated__c = true;
            }
            update overdueComplaints;
            NotificationService.notifyAdmins(overdueComplaints, 'SLA Overdue Escalation');
        }

        return overdueComplaints;
    }
}
