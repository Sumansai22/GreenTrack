@isTest
private class GreenTrackGuestUserSecurityTest {

    @testSetup
    static void setupData() {
        Collection_Team__c team = GreenTrackTestDataFactory.createTeam('Security Test Team', 'STT-01', 'North Zone');
        Cleaning_Worker__c worker = GreenTrackTestDataFactory.createWorker('Security Test Worker', 'EMP-SEC-01', team.Id, 'North Zone');
        
        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Confidential Resident Dump', 'Hazardous Waste', 'Critical', 'North Zone');
        complaint.Resident_Email__c = 'confidential@example.com';
        complaint.Resident_Phone__c = '555-999-8888';
        insert complaint;

        Recycling_Request__c recycling = new Recycling_Request__c(
            Resident_Name__c = 'Private Resident',
            Resident_Email__c = 'confidential@example.com',
            Resident_Phone__c = '555-999-8888',
            Pickup_Address__c = '123 Private St',
            Pickup_Date__c = Date.today().addDays(2),
            Waste_Category__c = 'Plastics',
            Estimated_Quantity__c = 10,
            Status__c = 'Submitted'
        );
        insert recycling;
    }

    @isTest
    static void testGuestUserCannotAccessComplaintsOrPII() {
        User guestUser = [
            SELECT Id FROM User 
            WHERE Profile.Name = 'GreenTrack Profile' AND IsActive = true 
            LIMIT 1
        ];

        System.runAs(guestUser) {
            // 1. Test getComplaints returns 0 records for Guest User
            List<Waste_Complaint__c> complaints = WasteAnalyticsService.getComplaints('All', 'All', '');
            System.assertEquals(0, complaints.size(), 'Guest user must not receive any complaints or resident PII');

            // 2. Test getRecyclingRequests returns 0 records for Guest User
            List<Recycling_Request__c> recyclingList = RecyclingRequestService.getRecyclingRequests('All');
            System.assertEquals(0, recyclingList.size(), 'Guest user must not receive any recycling requests or resident PII');

            // 3. Test checkPotentialDuplicates returns 0 records for Guest User
            List<Waste_Complaint__c> duplicates = WasteComplaintDuplicateService.checkPotentialDuplicates('North Zone', 'Hazardous Waste', '100 Green Ave, North Zone');
            System.assertEquals(0, duplicates.size(), 'Guest user must not be able to probe existing tickets via duplicate checker');

            // 4. Test direct SOQL queries on custom objects
            List<Waste_Complaint__c> soqlComplaints = [SELECT Id FROM Waste_Complaint__c];
            System.assertEquals(0, soqlComplaints.size(), 'Guest user direct SOQL must return 0 complaints');

            List<Recycling_Request__c> soqlRecycling = [SELECT Id FROM Recycling_Request__c];
            System.assertEquals(0, soqlRecycling.size(), 'Guest user direct SOQL must return 0 recycling requests');
        }
    }
}
