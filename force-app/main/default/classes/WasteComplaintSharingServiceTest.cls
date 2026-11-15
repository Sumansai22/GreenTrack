/**
 * @description Comprehensive unit tests for WasteComplaintSharingService and Apex-managed
 * record sharing on Waste_Complaint__c.
 * Validates:
 *  - Team Leader sharing on insert and update
 *  - Cleaning Worker sharing on insert and update
 *  - Reassignment and obsolete share removal
 *  - Preservation of unrelated manual shares
 *  - Null assignments and unassignments
 *  - Bulk handling of 200 records per transaction
 *  - Duplicate prevention when Leader and Worker share the same user identity
 */
@IsTest
private class WasteComplaintSharingServiceTest {

    @TestSetup
    static void setupUsers() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            GreenTrackTestDataFactory.createTestUser('ldr1');
            GreenTrackTestDataFactory.createTestUser('ldr2');
            GreenTrackTestDataFactory.createTestUser('wrk1');
            GreenTrackTestDataFactory.createTestUser('wrk2');
            GreenTrackTestDataFactory.createTestUser('unrel');
            GreenTrackTestDataFactory.createTestUser('same');
        }
    }

    private static User getUser(String alias) {
        return [SELECT Id, Alias FROM User WHERE Alias = :alias LIMIT 1];
    }

    @IsTest
    static void testTeamLeaderSharingOnInsert() {
        User leader1 = getUser('ldr1');
        Collection_Team__c team1 = GreenTrackTestDataFactory.createTeamWithLeaderUser('Alpha Squad', 'AS-01', 'North District', leader1.Id);

        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Illegal Dumpsite', 'Illegal Dumping', 'High', 'North District');
        complaint.Assigned_Team__c = team1.Id;

        Test.startTest();
        insert complaint;
        Test.stopTest();

        List<Waste_Complaint__Share> shares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM Waste_Complaint__Share
            WHERE ParentId = :complaint.Id AND UserOrGroupId = :leader1.Id AND RowCause = 'Manual'
        ];

        System.assertEquals(1, shares.size(), 'Team Leader must receive exactly one manual share record');
        System.assertEquals('Edit', shares[0].AccessLevel, 'Team Leader must have Read/Write (Edit) access');
    }

    @IsTest
    static void testCleaningWorkerSharingOnInsert() {
        User workerUser = getUser('wrk1');
        Collection_Team__c team = GreenTrackTestDataFactory.createTeam('Bravo Squad', 'BS-02', 'South District');
        Cleaning_Worker__c worker = GreenTrackTestDataFactory.createWorkerWithUser('John Doe', 'W-501', team.Id, 'South District', workerUser.Id);

        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Overflowing Bin', 'Overflowing Dustbin', 'Medium', 'South District');
        complaint.Assigned_Worker__c = worker.Id;

        Test.startTest();
        insert complaint;
        Test.stopTest();

        List<Waste_Complaint__Share> shares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM Waste_Complaint__Share
            WHERE ParentId = :complaint.Id AND UserOrGroupId = :workerUser.Id AND RowCause = 'Manual'
        ];

        System.assertEquals(1, shares.size(), 'Cleaning Worker must receive exactly one manual share record');
        System.assertEquals('Edit', shares[0].AccessLevel, 'Cleaning Worker must have Read/Write (Edit) access');
    }

    @IsTest
    static void testBothLeaderAndWorkerSharing() {
        User leaderUser = getUser('ldr1');
        User workerUser = getUser('wrk1');

        Collection_Team__c team = GreenTrackTestDataFactory.createTeamWithLeaderUser('Gamma Squad', 'GS-03', 'East District', leaderUser.Id);
        Cleaning_Worker__c worker = GreenTrackTestDataFactory.createWorkerWithUser('Jane Smith', 'W-502', team.Id, 'East District', workerUser.Id);

        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Hazardous Chemical', 'Hazardous Waste', 'Critical', 'East District');
        complaint.Assigned_Team__c = team.Id;
        complaint.Assigned_Worker__c = worker.Id;

        Test.startTest();
        insert complaint;
        Test.stopTest();

        Map<Id, Waste_Complaint__Share> userShareMap = new Map<Id, Waste_Complaint__Share>();
        for (Waste_Complaint__Share sh : [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM Waste_Complaint__Share
            WHERE ParentId = :complaint.Id AND RowCause = 'Manual'
        ]) {
            userShareMap.put(sh.UserOrGroupId, sh);
        }

        System.assert(userShareMap.containsKey(leaderUser.Id), 'Leader must receive share');
        System.assertEquals('Edit', userShareMap.get(leaderUser.Id).AccessLevel);
        System.assert(userShareMap.containsKey(workerUser.Id), 'Worker must receive share');
        System.assertEquals('Edit', userShareMap.get(workerUser.Id).AccessLevel);
    }

    @IsTest
    static void testAssignmentChangesAndObsoleteShareRemoval() {
        User leader1 = getUser('ldr1');
        User leader2 = getUser('ldr2');
        User worker1 = getUser('wrk1');
        User worker2 = getUser('wrk2');

        Collection_Team__c team1 = GreenTrackTestDataFactory.createTeamWithLeaderUser('Team One', 'T-01', 'Sector 1', leader1.Id);
        Collection_Team__c team2 = GreenTrackTestDataFactory.createTeamWithLeaderUser('Team Two', 'T-02', 'Sector 2', leader2.Id);

        Cleaning_Worker__c wrk1 = GreenTrackTestDataFactory.createWorkerWithUser('Worker One', 'WO-1', team1.Id, 'Sector 1', worker1.Id);
        Cleaning_Worker__c wrk2 = GreenTrackTestDataFactory.createWorkerWithUser('Worker Two', 'WO-2', team2.Id, 'Sector 2', worker2.Id);

        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Trash Pile', 'Household Waste', 'Low', 'Sector 1');
        complaint.Assigned_Team__c = team1.Id;
        complaint.Assigned_Worker__c = wrk1.Id;
        insert complaint;

        // Verify initial shares
        List<Waste_Complaint__Share> initialShares = [
            SELECT Id, UserOrGroupId FROM Waste_Complaint__Share WHERE ParentId = :complaint.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(2, initialShares.size(), 'Initial shares for leader1 and worker1 must exist');

        Test.startTest();
        // Reassign to Team 2 and Worker 2
        complaint.Assigned_Team__c = team2.Id;
        complaint.Assigned_Worker__c = wrk2.Id;
        update complaint;
        Test.stopTest();

        List<Waste_Complaint__Share> updatedShares = [
            SELECT Id, UserOrGroupId, AccessLevel FROM Waste_Complaint__Share WHERE ParentId = :complaint.Id AND RowCause = 'Manual'
        ];

        Set<Id> sharedUserIds = new Set<Id>();
        for (Waste_Complaint__Share sh : updatedShares) {
            sharedUserIds.add(sh.UserOrGroupId);
            System.assertEquals('Edit', sh.AccessLevel, 'Active assigned users must have Edit access');
        }

        System.assert(!sharedUserIds.contains(leader1.Id), 'Old team leader share must be deleted');
        System.assert(!sharedUserIds.contains(worker1.Id), 'Old worker share must be deleted');
        System.assert(sharedUserIds.contains(leader2.Id), 'New team leader share must be created');
        System.assert(sharedUserIds.contains(worker2.Id), 'New worker share must be created');
    }

    @IsTest
    static void testPreserveUnrelatedManualShares() {
        User leader1 = getUser('ldr1');
        User leader2 = getUser('ldr2');
        User unrelatedUser = getUser('unrel');

        Collection_Team__c team1 = GreenTrackTestDataFactory.createTeamWithLeaderUser('Team A', 'TA-01', 'West Zone', leader1.Id);
        Collection_Team__c team2 = GreenTrackTestDataFactory.createTeamWithLeaderUser('Team B', 'TB-02', 'West Zone', leader2.Id);

        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Biohazard', 'Hazardous Waste', 'High', 'West Zone');
        complaint.Assigned_Team__c = team1.Id;
        insert complaint;

        // Manually grant unrelated user Read access (e.g. auditor or supervisor)
        Waste_Complaint__Share unrelatedShare = new Waste_Complaint__Share(
            ParentId = complaint.Id,
            UserOrGroupId = unrelatedUser.Id,
            AccessLevel = 'Read',
            RowCause = 'Manual'
        );
        insert unrelatedShare;

        Test.startTest();
        // Reassign to Team 2
        complaint.Assigned_Team__c = team2.Id;
        update complaint;
        Test.stopTest();

        List<Waste_Complaint__Share> postUpdateShares = [
            SELECT Id, UserOrGroupId, AccessLevel, RowCause
            FROM Waste_Complaint__Share
            WHERE ParentId = :complaint.Id AND RowCause = 'Manual'
        ];

        Set<Id> userIdsWithShare = new Set<Id>();
        for (Waste_Complaint__Share sh : postUpdateShares) {
            userIdsWithShare.add(sh.UserOrGroupId);
        }

        System.assert(!userIdsWithShare.contains(leader1.Id), 'Old leader share must be removed');
        System.assert(userIdsWithShare.contains(leader2.Id), 'New leader share must be granted');
        System.assert(userIdsWithShare.contains(unrelatedUser.Id), 'Unrelated manual share must NOT be deleted');
    }

    @IsTest
    static void testNullAssignmentsAndUnassign() {
        User leader1 = getUser('ldr1');

        // 1. Initial complaint with no team available/assigned
        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Litter on sidewalk', 'Household Waste', 'Low', 'Remote Area');
        insert complaint;

        List<Waste_Complaint__Share> initialShares = [
            SELECT Id FROM Waste_Complaint__Share WHERE ParentId = :complaint.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(0, initialShares.size(), 'Unassigned complaint must have 0 manual shares');

        // 2. Create team and assign team
        Collection_Team__c team1 = GreenTrackTestDataFactory.createTeamWithLeaderUser('Team Clean', 'TC-01', 'Central Area', leader1.Id);
        complaint.Assigned_Team__c = team1.Id;
        update complaint;

        List<Waste_Complaint__Share> assignedShares = [
            SELECT Id, UserOrGroupId FROM Waste_Complaint__Share WHERE ParentId = :complaint.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(1, assignedShares.size(), 'Assigning team must create manual share');
        System.assertEquals(leader1.Id, assignedShares[0].UserOrGroupId);

        Test.startTest();
        // Make team inactive so automatic assignment flow does not immediately reassign
        team1.Active_Status__c = false;
        update team1;

        // 3. Unassign team
        complaint.Assigned_Team__c = null;
        update complaint;
        Test.stopTest();

        List<Waste_Complaint__Share> unassignedShares = [
            SELECT Id FROM Waste_Complaint__Share WHERE ParentId = :complaint.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(0, unassignedShares.size(), 'Unassigning team must remove obsolete manual share');
    }

    @IsTest
    static void testNoDuplicateSharesWhenLeaderAndWorkerAreSameUser() {
        User sharedUser = getUser('same');

        Collection_Team__c team = GreenTrackTestDataFactory.createTeamWithLeaderUser('Solo Team', 'SOLO-1', 'Uptown', sharedUser.Id);
        Cleaning_Worker__c worker = GreenTrackTestDataFactory.createWorkerWithUser('Solo Worker', 'SW-1', team.Id, 'Uptown', sharedUser.Id);

        Waste_Complaint__c complaint = GreenTrackTestDataFactory.buildComplaint('Dual Role Complaint', 'Plastic Waste', 'Medium', 'Uptown');
        complaint.Assigned_Team__c = team.Id;
        complaint.Assigned_Worker__c = worker.Id;

        Test.startTest();
        insert complaint;
        Test.stopTest();

        List<Waste_Complaint__Share> shares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel
            FROM Waste_Complaint__Share
            WHERE ParentId = :complaint.Id AND UserOrGroupId = :sharedUser.Id AND RowCause = 'Manual'
        ];

        System.assertEquals(1, shares.size(), 'Exactly one share must be created even if user is both leader and worker');
        System.assertEquals('Edit', shares[0].AccessLevel);
    }

    @IsTest
    static void testBulkSharing200Records() {
        User leaderUser = getUser('ldr1');
        User workerUser = getUser('wrk1');

        Collection_Team__c team = GreenTrackTestDataFactory.createTeamWithLeaderUser('Bulk Team', 'BT-99', 'Metro Area', leaderUser.Id);
        Cleaning_Worker__c worker = GreenTrackTestDataFactory.createWorkerWithUser('Bulk Worker', 'BW-99', team.Id, 'Metro Area', workerUser.Id);

        List<Waste_Complaint__c> bulkComplaints = new List<Waste_Complaint__c>();
        for (Integer i = 0; i < 200; i++) {
            Waste_Complaint__c c = GreenTrackTestDataFactory.buildComplaint('Bulk Waste ' + i, 'Household Waste', 'Medium', 'Metro Area');
            c.Assigned_Team__c = team.Id;
            c.Assigned_Worker__c = worker.Id;
            bulkComplaints.add(c);
        }

        Test.startTest();
        insert bulkComplaints;
        Test.stopTest();

        List<Waste_Complaint__Share> bulkShares = [
            SELECT Id, ParentId, UserOrGroupId
            FROM Waste_Complaint__Share
            WHERE ParentId IN :bulkComplaints AND RowCause = 'Manual'
        ];

        // 200 complaints x 2 assigned users = 400 shares
        System.assertEquals(400, bulkShares.size(), 'All 200 bulk complaints must receive shares for leader and worker');
    }
}
