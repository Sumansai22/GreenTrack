/**
 * @description Unit tests for NotificationService dispatch logic and logging tasks.
 */
@IsTest
private class NotificationServiceTest {

    @IsTest
    static void testNotifyResidentAndAdmins() {
        Waste_Complaint__c wc = GreenTrackTestDataFactory.createComplaint(
            'Biohazard Spillage',
            'Hazardous Waste',
            'Critical',
            'South Zone'
        );

        Test.startTest();
        NotificationService.notifyResidentStatusChange(new List<Waste_Complaint__c>{ wc }, 'Resolved');
        NotificationService.notifyAdmins(new List<Waste_Complaint__c>{ wc }, 'Immediate Evacuation Required');
        Test.stopTest();

        List<Task> loggedTasks = [SELECT Id, Subject, WhatId FROM Task WHERE WhatId = :wc.Id];
        System.assert(!loggedTasks.isEmpty(), 'Notification tasks should be logged');
    }
}
