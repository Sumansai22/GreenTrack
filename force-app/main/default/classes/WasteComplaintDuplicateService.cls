/**
 * @description Duplicate detection service identifying overlapping complaints
 * within the same geographical area and waste category.
 */
public with sharing class WasteComplaintDuplicateService {
    
    /**
     * @description Real-time duplicate check accessible by LWC and Apex
     * @param area Complaint area/neighborhood
     * @param wasteType Picklist value of waste category
     * @param streetAddress Street address
     * @return List of potentially matching active complaints
     */
    @AuraEnabled(cacheable=true)
    public static List<Waste_Complaint__c> checkPotentialDuplicates(String area, String wasteType, String streetAddress) {
        if (String.isBlank(area) || String.isBlank(wasteType)) {
            return new List<Waste_Complaint__c>();
        }

        DateTime thresholdTime = DateTime.now().addDays(-2);

        String searchQuery = 'SELECT Id, Name, Complaint_Title__c, Street_Address__c, Area__c, ' +
                             'Waste_Type__c, Severity__c, Status__c, Reported_Date__c, ' +
                             'Assigned_Team__r.Name ' +
                             'FROM Waste_Complaint__c ' +
                             'WHERE Area__c = :area ' +
                             'AND Waste_Type__c = :wasteType ' +
                             'AND Status__c NOT IN (\'Resolved\', \'Rejected\') ' +
                             'AND Reported_Date__c >= :thresholdTime ' +
                             'ORDER BY Reported_Date__c DESC ' +
                             'LIMIT 5';

        return Database.query(searchQuery);
    }

    /**
     * @description Analyzes incoming records in trigger and annotates or logs suspected duplicate occurrences
     * @param complaints New complaints being inserted
     */
    public static void tagDuplicateComplaints(List<Waste_Complaint__c> complaints) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        Set<String> areas = new Set<String>();
        Set<String> wasteTypes = new Set<String>();

        for (Waste_Complaint__c wc : complaints) {
            if (String.isNotBlank(wc.Area__c)) {
                areas.add(wc.Area__c);
            }
            if (String.isNotBlank(wc.Waste_Type__c)) {
                wasteTypes.add(wc.Waste_Type__c);
            }
        }

        if (areas.isEmpty() || wasteTypes.isEmpty()) {
            return;
        }

        DateTime thresholdTime = DateTime.now().addDays(-2);

        List<Waste_Complaint__c> existingActive = [
            SELECT Id, Name, Area__c, Waste_Type__c, Street_Address__c, Status__c
            FROM Waste_Complaint__c
            WHERE Area__c IN :areas
              AND Waste_Type__c IN :wasteTypes
              AND Status__c NOT IN ('Resolved', 'Rejected')
              AND Reported_Date__c >= :thresholdTime
        ];

        Map<String, Waste_Complaint__c> existingMap = new Map<String, Waste_Complaint__c>();
        for (Waste_Complaint__c ex : existingActive) {
            String key = (ex.Area__c != null ? ex.Area__c.toLowerCase().trim() : '') + '|' +
                         (ex.Waste_Type__c != null ? ex.Waste_Type__c.toLowerCase().trim() : '');
            existingMap.put(key, ex);
        }

        for (Waste_Complaint__c wc : complaints) {
            String key = (wc.Area__c != null ? wc.Area__c.toLowerCase().trim() : '') + '|' +
                         (wc.Waste_Type__c != null ? wc.Waste_Type__c.toLowerCase().trim() : '');

            if (existingMap.containsKey(key)) {
                Waste_Complaint__c match = existingMap.get(key);
                String tag = '[Potential Duplicate of ' + match.Name + '] ';
                if (wc.Description__c != null && !wc.Description__c.contains(tag)) {
                    wc.Description__c = tag + wc.Description__c;
                }
            }
        }
    }
}
