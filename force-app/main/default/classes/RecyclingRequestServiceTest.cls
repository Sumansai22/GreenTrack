/**
 * @description Unit tests for RecyclingRequestService methods, validations, and completions.
 */
@IsTest
private class RecyclingRequestServiceTest {

    @TestSetup
    static void setupData() {
        GreenTrackTestDataFactory.createTeam('Recycle Squad', 'RS-01', 'Eco District');
    }

    @IsTest
    static void testCreateRecyclingRequestSuccess() {
        Recycling_Request__c req = new Recycling_Request__c(
            Resident_Name__c = 'Elena Gomez',
            Resident_Email__c = 'elena@example.org',
            Resident_Phone__c = '555-4321',
            Waste_Category__c = 'Plastics',
            Estimated_Quantity__c = 15.0,
            Pickup_Address__c = '321 Maple Road',
            Pickup_Date__c = Date.today().addDays(2)
        );

        Test.startTest();
        Id reqId = RecyclingRequestService.createRecyclingRequest(req);
        Test.stopTest();

        Recycling_Request__c saved = [
            SELECT Id, Status__c, Assigned_Team__c
            FROM Recycling_Request__c
            WHERE Id = :reqId
        ];

        System.assertEquals('Scheduled', saved.Status__c);
        System.assertNotEquals(null, saved.Assigned_Team__c);
    }

    @IsTest
    static void testCompleteRecyclingRequest() {
        Recycling_Request__c req = GreenTrackTestDataFactory.createRecyclingRequest('Tom Brown', 'Metals', 40.0, Date.today().addDays(1));

        Test.startTest();
        RecyclingRequestService.completeRecyclingRequest(req.Id);
        Test.stopTest();

        Recycling_Request__c completed = [
            SELECT Id, Status__c, Completion_Date__c
            FROM Recycling_Request__c
            WHERE Id = :req.Id
        ];

        System.assertEquals('Completed', completed.Status__c);
        System.assertNotEquals(null, completed.Completion_Date__c);
    }

    @IsTest
    static void testGetRecyclingRequests() {
        GreenTrackTestDataFactory.createRecyclingRequest('User A', 'Glass', 12.0, Date.today().addDays(1));
        GreenTrackTestDataFactory.createRecyclingRequest('User B', 'Paper & Cardboard', 20.0, Date.today().addDays(2));

        Test.startTest();
        List<Recycling_Request__c> all = RecyclingRequestService.getRecyclingRequests('All');
        List<Recycling_Request__c> submitted = RecyclingRequestService.getRecyclingRequests('Submitted');
        Test.stopTest();

        System.assert(all.size() >= 2);
    }
}
