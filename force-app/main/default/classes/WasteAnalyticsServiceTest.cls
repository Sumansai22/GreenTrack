/**
 * @description Unit tests for WasteAnalyticsService KPI queries, aggregations, and trends.
 */
@IsTest
private class WasteAnalyticsServiceTest {

    @TestSetup
    static void setupData() {
        Collection_Team__c team = GreenTrackTestDataFactory.createTeam('Alpha Team', 'AT-01', 'North District');
        Waste_Complaint__c wc1 = GreenTrackTestDataFactory.createComplaint('Trash A', 'Household Waste', 'Low', 'North District');
        Waste_Complaint__c wc2 = GreenTrackTestDataFactory.createComplaint('Trash B', 'Hazardous Waste', 'Critical', 'North District');

        wc1.Status__c = 'Resolved';
        wc1.Resolution_Notes__c = 'Cleaned successfully';
        wc1.Resolution_Date__c = DateTime.now();
        update wc1;

        GreenTrackTestDataFactory.createRecyclingRequest('Recycler One', 'Plastics', 50.0, Date.today().addDays(1));
        GreenTrackTestDataFactory.createLocation('Hotspot North', 'North District', 'High');
    }

    @IsTest
    static void testGetDashboardMetrics() {
        Test.startTest();
        WasteAnalyticsService.DashboardSummary ds = WasteAnalyticsService.getDashboardMetrics();
        Test.stopTest();

        System.assertNotEquals(null, ds);
        System.assert(ds.totalComplaints >= 2, 'Total complaints count');
        System.assert(ds.criticalComplaints >= 1, 'Critical count');
        System.assert(ds.recyclingRequests >= 1, 'Recycling count');
    }

    @IsTest
    static void testGetComplaintsBreakdowns() {
        Test.startTest();
        List<WasteAnalyticsService.ChartItem> byType = WasteAnalyticsService.getComplaintsByWasteType();
        List<WasteAnalyticsService.ChartItem> bySev = WasteAnalyticsService.getComplaintsBySeverity();
        List<WasteAnalyticsService.ChartItem> byArea = WasteAnalyticsService.getComplaintsByArea();
        List<WasteAnalyticsService.MonthlyTrendItem> trends = WasteAnalyticsService.getMonthlyTrends();
        WasteAnalyticsService.SLAComplianceData slaData = WasteAnalyticsService.getSLAComplianceMetrics();
        List<Collection_Team__c> teams = WasteAnalyticsService.getTeamPerformance();
        List<Waste_Location__c> hotspots = WasteAnalyticsService.getWasteHotspots();
        List<Waste_Complaint__c> tableList = WasteAnalyticsService.getComplaints('All', 'All', '');
        Test.stopTest();

        System.assert(!byType.isEmpty());
        System.assert(!bySev.isEmpty());
        System.assert(!byArea.isEmpty());
        System.assertEquals(12, trends.size());
        System.assertNotEquals(null, slaData);
        System.assert(!teams.isEmpty());
        System.assert(!hotspots.isEmpty());
        System.assert(!tableList.isEmpty());
    }

    @IsTest
    static void testGetUserRoleContextAdmin() {
        Test.startTest();
        WasteAnalyticsService.UserRoleInfo info = WasteAnalyticsService.getUserRoleContext();
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals(true, info.isAuthenticated);
        System.assertEquals(false, info.isGuest);
    }

    @IsTest
    static void testGetUserRoleContextGuest() {
        User guestUser = [
            SELECT Id FROM User 
            WHERE Profile.Name = 'GreenTrack Profile' AND IsActive = true 
            LIMIT 1
        ];

        System.runAs(guestUser) {
            Test.startTest();
            WasteAnalyticsService.UserRoleInfo info = WasteAnalyticsService.getUserRoleContext();
            Test.stopTest();

            System.assertNotEquals(null, info);
            System.assertEquals(true, info.isGuest);
            System.assertEquals(false, info.isAuthenticated);
            System.assertEquals(false, info.isAdmin);
            System.assertEquals(false, info.isTeamLeader);
            System.assertEquals(false, info.isWorker);
        }
    }
}
