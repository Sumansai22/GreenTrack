/**
 * @description Unit tests for SLAService calculation, custom metadata integration,
 * and escalation scans.
 */
@IsTest
private class SLAServiceTest {

    @IsTest
    static void testSLACalculationsForDifferentSeverities() {
        Waste_Complaint__c cLow = GreenTrackTestDataFactory.buildComplaint('Low Issue', 'Household Waste', 'Low', 'Zone A');
        Waste_Complaint__c cMed = GreenTrackTestDataFactory.buildComplaint('Med Issue', 'Organic Waste', 'Medium', 'Zone A');
        Waste_Complaint__c cHigh = GreenTrackTestDataFactory.buildComplaint('High Issue', 'Hazardous Waste', 'High', 'Zone A');
        Waste_Complaint__c cCrit = GreenTrackTestDataFactory.buildComplaint('Crit Issue', 'Industrial Waste', 'Critical', 'Zone A');

        List<Waste_Complaint__c> testList = new List<Waste_Complaint__c>{ cLow, cMed, cHigh, cCrit };

        Test.startTest();
        SLAService.applySLAAndPriority(testList);
        Test.stopTest();

        System.assertEquals('Low', cLow.Priority__c);
        System.assertEquals('Medium', cMed.Priority__c);
        System.assertEquals('High', cHigh.Priority__c);
        System.assertEquals('Urgent', cCrit.Priority__c);
        System.assertEquals(true, cCrit.Is_Escalated__c);
        System.assertNotEquals(null, cLow.SLA_Deadline__c);
        System.assertNotEquals(null, cCrit.SLA_Deadline__c);
    }

    @IsTest
    static void testCheckAndEscalateBreachedComplaints() {
        Waste_Complaint__c overdue = GreenTrackTestDataFactory.buildComplaint('Old Issue', 'Illegal Dumping', 'Medium', 'Zone B');
        overdue.Reported_Date__c = DateTime.now().addDays(-5);
        overdue.SLA_Deadline__c = DateTime.now().addDays(-3);
        overdue.Is_Escalated__c = false;
        insert overdue;

        Test.startTest();
        List<Waste_Complaint__c> escalated = SLAService.checkAndEscalateBreachedComplaints();
        Test.stopTest();

        Waste_Complaint__c reloaded = [SELECT Id, Is_Escalated__c FROM Waste_Complaint__c WHERE Id = :overdue.Id];
        System.assertEquals(true, reloaded.Is_Escalated__c, 'Breached complaint must be escalated');
    }
}
