/**
 * @description Service class managing bulk recycling pickup requests,
 * scheduling, team allocations, and environmental metrics.
 */
public with sharing class RecyclingRequestService {
    
    /**
     * @description Schedules or books a new recycling pickup request
     * @param request Recycling_Request__c record to create
     * @return Id of the created record
     */
    @AuraEnabled
    public static Id createRecyclingRequest(Recycling_Request__c request) {
        if (request == null) {
            throw new AuraHandledException('Request payload cannot be empty.');
        }

        if (String.isBlank(request.Resident_Name__c)) {
            throw new AuraHandledException('Resident name is required.');
        }

        if (request.Pickup_Date__c != null && request.Pickup_Date__c < Date.today()) {
            throw new AuraHandledException('Pickup date cannot be in the past.');
        }

        if (request.Estimated_Quantity__c != null && request.Estimated_Quantity__c <= 0) {
            throw new AuraHandledException('Estimated quantity must be greater than zero kg.');
        }

        if (String.isBlank(request.Status__c)) {
            request.Status__c = 'Submitted';
        }

        // Auto-assign to available collection team if possible
        List<Collection_Team__c> teams = [
            SELECT Id FROM Collection_Team__c
            WHERE Active_Status__c = true AND Availability_Status__c = 'Available'
            LIMIT 1
        ];
        if (!teams.isEmpty()) {
            request.Assigned_Team__c = teams[0].Id;
            request.Status__c = 'Scheduled';
        }

        insert request;
        return request.Id;
    }

    /**
     * @description Marks a recycling request as completed
     */
    @AuraEnabled
    public static void completeRecyclingRequest(Id requestId) {
        if (requestId == null) {
            throw new AuraHandledException('Request ID is required.');
        }

        Recycling_Request__c req = [
            SELECT Id, Status__c, Completion_Date__c
            FROM Recycling_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        req.Status__c = 'Completed';
        req.Completion_Date__c = DateTime.now();
        update req;
    }

    /**
     * @description Retrieves active recycling requests for dashboard and resident views
     */
    @AuraEnabled(cacheable=true)
    public static List<Recycling_Request__c> getRecyclingRequests(String statusFilter) {
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            return [
                SELECT Id, Name, Resident_Name__c, Resident_Email__c, Resident_Phone__c,
                       Waste_Category__c, Estimated_Quantity__c, Pickup_Address__c,
                       Pickup_Date__c, Status__c, Assigned_Team__r.Name, Completion_Date__c
                FROM Recycling_Request__c
                WHERE Status__c = :statusFilter
                ORDER BY Pickup_Date__c ASC NULLS LAST, CreatedDate DESC
                LIMIT 100
            ];
        }

        return [
            SELECT Id, Name, Resident_Name__c, Resident_Email__c, Resident_Phone__c,
                   Waste_Category__c, Estimated_Quantity__c, Pickup_Address__c,
                   Pickup_Date__c, Status__c, Assigned_Team__r.Name, Completion_Date__c
            FROM Recycling_Request__c
            ORDER BY Pickup_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT 100
        ];
    }
}
