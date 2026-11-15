/**
 * @description Unit tests for WasteAssignmentService methods, manual assignment,
 * workload recalculations, and worker lookups.
 */
@IsTest
private class WasteAssignmentServiceTest {

    @TestSetup
    static void setupData() {
        Collection_Team__c teamEast = GreenTrackTestDataFactory.createTeam('East Squad', 'ES-01', 'East Zone');
        Collection_Team__c teamWest = GreenTrackTestDataFactory.createTeam('West Squad', 'WS-01', 'West Zone');

        GreenTrackTestDataFactory.createWorker('David Worker', 'EMP-E1', teamEast.Id, 'East Zone');
        GreenTrackTestDataFactory.createWorker('Sarah Worker', 'EMP-W1', teamWest.Id, 'West Zone');
    }

    @IsTest
    static void testAutoAssignToAreaMatchingTeam() {
        Test.startTest();
        Waste_Complaint__c wc = GreenTrackTestDataFactory.createComplaint(
            'East Zone Garbage Accumulation',
            'Household Waste',
            'Medium',
            'East Zone'
        );
        Test.stopTest();

        Waste_Complaint__c inserted = [
            SELECT Id, Assigned_Team__r.Name, Status__c
            FROM Waste_Complaint__c
            WHERE Id = :wc.Id
        ];

        System.assertEquals('East Squad', inserted.Assigned_Team__r.Name, 'Should be assigned to East Squad');
        System.assertEquals('Assigned', inserted.Status__c);
    }

    @IsTest
    static void testManualAssignment() {
        Waste_Complaint__c wc = GreenTrackTestDataFactory.createComplaint(
            'Unassigned Report',
            'Plastic Waste',
            'Low',
            'Other Zone'
        );

        Collection_Team__c team = [SELECT Id FROM Collection_Team__c WHERE Name = 'West Squad' LIMIT 1];
        Cleaning_Worker__c worker = [SELECT Id FROM Cleaning_Worker__c WHERE Name = 'Sarah Worker' LIMIT 1];

        Test.startTest();
        WasteAssignmentService.assignComplaintManually(wc.Id, team.Id, worker.Id);
        Test.stopTest();

        Waste_Complaint__c updatedWc = [
            SELECT Id, Assigned_Team__c, Assigned_Worker__c, Status__c
            FROM Waste_Complaint__c
            WHERE Id = :wc.Id
        ];

        System.assertEquals(team.Id, updatedWc.Assigned_Team__c);
        System.assertEquals(worker.Id, updatedWc.Assigned_Worker__c);
        System.assertEquals('Assigned', updatedWc.Status__c);
    }

    @IsTest
    static void testGetAvailableTeamsAndWorkers() {
        Test.startTest();
        List<Collection_Team__c> allTeams = WasteAssignmentService.getAvailableTeams(null);
        List<Collection_Team__c> eastTeams = WasteAssignmentService.getAvailableTeams('East Zone');
        List<Cleaning_Worker__c> allWorkers = WasteAssignmentService.getWorkersByTeam(null);
        Test.stopTest();

        System.assert(allTeams.size() >= 2, 'Should return available teams');
        System.assert(!eastTeams.isEmpty(), 'Should return filtered east teams');
        System.assert(allWorkers.size() >= 2, 'Should return all workers');
    }
}
