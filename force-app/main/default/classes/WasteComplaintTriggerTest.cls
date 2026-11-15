/**
 * @description Comprehensive test suite for WasteComplaintTrigger and WasteComplaintTriggerHandler.
 */
@IsTest
private class WasteComplaintTriggerTest {

    @TestSetup
    static void setupTestData() {
        Collection_Team__c team = GreenTrackTestDataFactory.createTeam('Central Cleansing', 'CC-01', 'Central Downtown');
        GreenTrackTestDataFactory.createWorker('Marcus Cole', 'W-101', team.Id, 'Central Downtown');
    }

    @IsTest
    static void testComplaintInsertAndAutoAssignment() {
        Test.startTest();
        Waste_Complaint__c wc = GreenTrackTestDataFactory.buildComplaint(
            'Overflowing Dustbin at Central Square',
            'Overflowing Dustbin',
            'High',
            'Central Downtown'
        );
        insert wc;
        Test.stopTest();

        Waste_Complaint__c inserted = [
            SELECT Id, Priority__c, Status__c, Assigned_Team__c, SLA_Deadline__c, Is_Escalated__c
            FROM Waste_Complaint__c
            WHERE Id = :wc.Id
        ];

        System.assertEquals('High', inserted.Priority__c, 'Priority should be set to High');
        System.assertEquals('Assigned', inserted.Status__c, 'Complaint should be auto-assigned to Central Downtown team');
        System.assertNotEquals(null, inserted.Assigned_Team__c, 'Team lookup should be populated');
        System.assertNotEquals(null, inserted.SLA_Deadline__c, 'SLA deadline should be populated');
    }

    @IsTest
    static void testCriticalComplaintAutoEscalation() {
        Test.startTest();
        Waste_Complaint__c wc = GreenTrackTestDataFactory.buildComplaint(
            'Hazardous Chemical Leak',
            'Hazardous Waste',
            'Critical',
            'Central Downtown'
        );
        insert wc;
        Test.stopTest();

        Waste_Complaint__c inserted = [
            SELECT Id, Priority__c, Is_Escalated__c, SLA_Deadline__c
            FROM Waste_Complaint__c
            WHERE Id = :wc.Id
        ];

        System.assertEquals('Urgent', inserted.Priority__c, 'Critical complaint must have Urgent priority');
        System.assertEquals(true, inserted.Is_Escalated__c, 'Critical complaint must be auto-escalated');
    }

    @IsTest
    static void testResolutionValidationSuccess() {
        Waste_Complaint__c wc = GreenTrackTestDataFactory.createComplaint(
            'Plastic Spill',
            'Plastic Waste',
            'Medium',
            'Central Downtown'
        );

        Test.startTest();
        wc.Status__c = 'Resolved';
        wc.Resolution_Notes__c = 'Cleared 4 bags of plastic and sanitized area.';
        update wc;
        Test.stopTest();

        Waste_Complaint__c resolved = [
            SELECT Id, Status__c, Resolution_Date__c, Resolution_Notes__c
            FROM Waste_Complaint__c
            WHERE Id = :wc.Id
        ];

        System.assertEquals('Resolved', resolved.Status__c, 'Status should be Resolved');
        System.assertNotEquals(null, resolved.Resolution_Date__c, 'Resolution date should be auto-stamped');
    }

    @IsTest
    static void testResolutionValidationFailure() {
        Waste_Complaint__c wc = GreenTrackTestDataFactory.createComplaint(
            'Plastic Spill',
            'Plastic Waste',
            'Medium',
            'Central Downtown'
        );

        Test.startTest();
        wc.Status__c = 'Resolved';
        wc.Resolution_Notes__c = null;
        try {
            update wc;
            System.assert(false, 'Should have thrown an error when resolving without notes');
        } catch (DmlException ex) {
            System.assert(ex.getMessage().contains('Resolution notes are required') || ex.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'),
                          'Expected resolution notes validation error');
        }
        Test.stopTest();
    }

    @IsTest
    static void testReopenComplaint() {
        Waste_Complaint__c wc = GreenTrackTestDataFactory.createComplaint(
            'Plastic Spill',
            'Plastic Waste',
            'Medium',
            'Central Downtown'
        );
        wc.Status__c = 'Resolved';
        wc.Resolution_Notes__c = 'Completed initially';
        update wc;

        Test.startTest();
        wc.Status__c = 'Reopened';
        update wc;
        Test.stopTest();

        Waste_Complaint__c reopened = [
            SELECT Id, Status__c, Resolution_Date__c
            FROM Waste_Complaint__c
            WHERE Id = :wc.Id
        ];
        System.assertEquals('Reopened', reopened.Status__c);
        System.assertEquals(null, reopened.Resolution_Date__c, 'Resolution date should be cleared upon reopen');
    }

    @IsTest
    static void testDuplicateDetectionAnnotation() {
        Waste_Complaint__c first = GreenTrackTestDataFactory.createComplaint(
            'Illegal Dumping Point A',
            'Illegal Dumping',
            'High',
            'Central Downtown'
        );

        Test.startTest();
        Waste_Complaint__c second = GreenTrackTestDataFactory.buildComplaint(
            'Illegal Dumping Point B',
            'Illegal Dumping',
            'High',
            'Central Downtown'
        );
        insert second;
        Test.stopTest();

        Waste_Complaint__c retrievedSecond = [
            SELECT Id, Description__c
            FROM Waste_Complaint__c
            WHERE Id = :second.Id
        ];

        System.assert(retrievedSecond.Description__c.contains('Potential Duplicate'),
                      'Description should be annotated with potential duplicate tag');
    }

    @IsTest
    static void testBulkComplaintProcessing() {
        List<Waste_Complaint__c> bulkList = new List<Waste_Complaint__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkList.add(GreenTrackTestDataFactory.buildComplaint(
                'Bulk Waste Complaint #' + i,
                'Household Waste',
                'Medium',
                'Central Downtown'
            ));
        }

        Test.startTest();
        insert bulkList;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Waste_Complaint__c];
        System.assert(count >= 200, 'All bulk records should be inserted without governor limit breaches');

        Collection_Team__c team = [SELECT Id, Total_Assigned_Complaints__c FROM Collection_Team__c LIMIT 1];
        System.assert(team.Total_Assigned_Complaints__c > 0, 'Team workload should reflect assigned bulk records');
    }
}
