/**
 * @description Analytics and reporting aggregation service delivering real-time database
 * metrics, SLA compliance stats, monthly trends, and environmental KPI calculations to GreenTrack LWCs.
 */
public with sharing class WasteAnalyticsService {
    
    public class DashboardSummary {
        @AuraEnabled public Integer totalComplaints { get; set; }
        @AuraEnabled public Integer newComplaints { get; set; }
        @AuraEnabled public Integer pendingComplaints { get; set; }
        @AuraEnabled public Integer inProgressComplaints { get; set; }
        @AuraEnabled public Integer resolvedComplaints { get; set; }
        @AuraEnabled public Integer criticalComplaints { get; set; }
        @AuraEnabled public Integer overdueComplaints { get; set; }
        @AuraEnabled public Integer recyclingRequests { get; set; }
        @AuraEnabled public Integer activeTeams { get; set; }
        @AuraEnabled public Decimal avgResolutionHours { get; set; }
        @AuraEnabled public Decimal totalRecycledKg { get; set; }
        @AuraEnabled public Decimal resolutionRatePercent { get; set; }
    }

    public class ChartItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer value { get; set; }
        @AuraEnabled public Decimal percentage { get; set; }

        public ChartItem(String label, Integer value) {
            this.label = label;
            this.value = value;
            this.percentage = 0.0;
        }
    }

    public class MonthlyTrendItem {
        @AuraEnabled public String monthName { get; set; }
        @AuraEnabled public Integer reportedCount { get; set; }
        @AuraEnabled public Integer resolvedCount { get; set; }

        public MonthlyTrendItem(String monthName, Integer reportedCount, Integer resolvedCount) {
            this.monthName = monthName;
            this.reportedCount = reportedCount;
            this.resolvedCount = resolvedCount;
        }
    }

    public class SLAComplianceData {
        @AuraEnabled public Integer compliantCount { get; set; }
        @AuraEnabled public Integer breachedCount { get; set; }
        @AuraEnabled public Decimal complianceRatePercent { get; set; }
    }

    public class UserRoleInfo {
        @AuraEnabled public Boolean isGuest { get; set; }
        @AuraEnabled public Boolean isAuthenticated { get; set; }
        @AuraEnabled public Boolean isAdmin { get; set; }
        @AuraEnabled public Boolean isTeamLeader { get; set; }
        @AuraEnabled public Boolean isWorker { get; set; }
        @AuraEnabled public Boolean isResident { get; set; }
        @AuraEnabled public String userName { get; set; }
        @AuraEnabled public String activeRole { get; set; }
    }

    /**
     * @description Returns current user role, authentication state, and permissible views
     */
    @AuraEnabled(cacheable=true)
    public static UserRoleInfo getUserRoleContext() {
        UserRoleInfo info = new UserRoleInfo();
        String userType = UserInfo.getUserType();
        info.userName = UserInfo.getName();
        info.isGuest = (userType == 'Guest');
        info.isAuthenticated = !info.isGuest;
        info.isAdmin = false;
        info.isTeamLeader = false;
        info.isWorker = false;
        info.isResident = false;
        info.activeRole = 'guest';

        if (info.isGuest) {
            return info;
        }

        // Query permission sets assigned to current user
        Set<String> permSets = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Name 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :UserInfo.getUserId()
        ]) {
            permSets.add(psa.PermissionSet.Name);
        }

        // Check profile as fallback for SysAdmin
        String profileName = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name;

        if (permSets.contains('GreenTrack_Municipal_Admin') || profileName == 'System Administrator') {
            info.isAdmin = true;
            info.isResident = true;
            info.activeRole = 'admin';
        } else if (permSets.contains('GreenTrack_Team_Leader')) {
            info.isTeamLeader = true;
            info.activeRole = 'team_leader';
        } else if (permSets.contains('GreenTrack_Cleaning_Worker')) {
            info.isWorker = true;
            info.activeRole = 'worker';
        } else if (permSets.contains('GreenTrack_Resident')) {
            info.isResident = true;
            info.activeRole = 'resident';
        } else {
            info.isResident = true;
            info.activeRole = 'resident';
        }

        return info;
    }

    /**
     * @description Calculates real-time KPI overview metrics from database records
     */
    @AuraEnabled(cacheable=true)
    public static DashboardSummary getDashboardMetrics() {
        DashboardSummary ds = new DashboardSummary();
        ds.totalComplaints = 0;
        ds.newComplaints = 0;
        ds.pendingComplaints = 0;
        ds.inProgressComplaints = 0;
        ds.resolvedComplaints = 0;
        ds.criticalComplaints = 0;
        ds.overdueComplaints = 0;
        ds.recyclingRequests = 0;
        ds.activeTeams = 0;
        ds.avgResolutionHours = 0;
        ds.totalRecycledKg = 0;
        ds.resolutionRatePercent = 0;

        // 1. Complaint Status breakdown
        for (AggregateResult ar : [
            SELECT Status__c st, COUNT(Id) cnt
            FROM Waste_Complaint__c
            GROUP BY Status__c
        ]) {
            String statusVal = (String)ar.get('st');
            Integer count = (Integer)ar.get('cnt');
            ds.totalComplaints += count;

            if (statusVal == 'New' || statusVal == 'Submitted') {
                ds.newComplaints += count;
                ds.pendingComplaints += count;
            } else if (statusVal == 'Assigned' || statusVal == 'Reopened') {
                ds.pendingComplaints += count;
            } else if (statusVal == 'In Progress') {
                ds.inProgressComplaints += count;
            } else if (statusVal == 'Resolved') {
                ds.resolvedComplaints += count;
            }
        }

        // 2. Critical & Overdue count
        DateTime nowTime = DateTime.now();
        ds.criticalComplaints = [
            SELECT COUNT()
            FROM Waste_Complaint__c
            WHERE Severity__c = 'Critical' AND Status__c NOT IN ('Resolved', 'Rejected')
        ];

        ds.overdueComplaints = [
            SELECT COUNT()
            FROM Waste_Complaint__c
            WHERE SLA_Deadline__c < :nowTime AND Status__c NOT IN ('Resolved', 'Rejected')
        ];

        // 3. Active teams
        ds.activeTeams = [
            SELECT COUNT()
            FROM Collection_Team__c
            WHERE Active_Status__c = true
        ];

        // 4. Recycling Requests & Total Recycled Volume
        for (AggregateResult ar : [
            SELECT COUNT(Id) cnt, SUM(Estimated_Quantity__c) qty
            FROM Recycling_Request__c
        ]) {
            ds.recyclingRequests = (Integer)ar.get('cnt');
            Decimal totalKg = (Decimal)ar.get('qty');
            ds.totalRecycledKg = totalKg != null ? totalKg.setScale(1) : 0;
        }

        // 5. Resolution Rate & Avg Resolution Hours
        if (ds.totalComplaints > 0) {
            ds.resolutionRatePercent = ((Decimal)ds.resolvedComplaints / (Decimal)ds.totalComplaints * 100).setScale(1);
        }

        List<Waste_Complaint__c> resolvedList = [
            SELECT Reported_Date__c, Resolution_Date__c
            FROM Waste_Complaint__c
            WHERE Status__c = 'Resolved'
              AND Reported_Date__c != null
              AND Resolution_Date__c != null
            LIMIT 200
        ];

        if (!resolvedList.isEmpty()) {
            Decimal totalHours = 0;
            for (Waste_Complaint__c r : resolvedList) {
                Long diffMillis = r.Resolution_Date__c.getTime() - r.Reported_Date__c.getTime();
                Decimal hours = (diffMillis / (1000.0 * 60.0 * 60.0));
                if (hours >= 0) {
                    totalHours += hours;
                }
            }
            ds.avgResolutionHours = (totalHours / resolvedList.size()).setScale(1);
        }

        return ds;
    }

    /**
     * @description Aggregates complaints by Waste Type picklist value
     */
    @AuraEnabled(cacheable=true)
    public static List<ChartItem> getComplaintsByWasteType() {
        List<ChartItem> results = new List<ChartItem>();
        Integer total = 0;

        for (AggregateResult ar : [
            SELECT Waste_Type__c wt, COUNT(Id) cnt
            FROM Waste_Complaint__c
            WHERE Waste_Type__c != null
            GROUP BY Waste_Type__c
            ORDER BY COUNT(Id) DESC
        ]) {
            String label = (String)ar.get('wt');
            Integer count = (Integer)ar.get('cnt');
            total += count;
            results.add(new ChartItem(label, count));
        }

        if (total > 0) {
            for (ChartItem item : results) {
                item.percentage = (((Decimal)item.value / total) * 100).setScale(1);
            }
        }

        return results;
    }

    /**
     * @description Aggregates complaints by Severity
     */
    @AuraEnabled(cacheable=true)
    public static List<ChartItem> getComplaintsBySeverity() {
        List<ChartItem> results = new List<ChartItem>();
        for (AggregateResult ar : [
            SELECT Severity__c sev, COUNT(Id) cnt
            FROM Waste_Complaint__c
            WHERE Severity__c != null
            GROUP BY Severity__c
        ]) {
            String label = (String)ar.get('sev');
            Integer count = (Integer)ar.get('cnt');
            results.add(new ChartItem(label, count));
        }
        return results;
    }

    /**
     * @description Aggregates complaints by Area
     */
    @AuraEnabled(cacheable=true)
    public static List<ChartItem> getComplaintsByArea() {
        List<ChartItem> results = new List<ChartItem>();
        for (AggregateResult ar : [
            SELECT Area__c arName, COUNT(Id) cnt
            FROM Waste_Complaint__c
            WHERE Area__c != null
            GROUP BY Area__c
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ]) {
            String label = (String)ar.get('arName');
            Integer count = (Integer)ar.get('cnt');
            results.add(new ChartItem(label, count));
        }
        return results;
    }

    /**
     * @description Monthly trends aggregated by calendar month
     */
    @AuraEnabled(cacheable=true)
    public static List<MonthlyTrendItem> getMonthlyTrends() {
        List<MonthlyTrendItem> trends = new List<MonthlyTrendItem>();
        Map<Integer, Integer> reportedByMonth = new Map<Integer, Integer>();
        Map<Integer, Integer> resolvedByMonth = new Map<Integer, Integer>();

        for (Integer i = 1; i <= 12; i++) {
            reportedByMonth.put(i, 0);
            resolvedByMonth.put(i, 0);
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(Reported_Date__c) m, COUNT(Id) cnt
            FROM Waste_Complaint__c
            WHERE Reported_Date__c != null
            GROUP BY CALENDAR_MONTH(Reported_Date__c)
        ]) {
            Integer m = (Integer)ar.get('m');
            Integer cnt = (Integer)ar.get('cnt');
            if (m != null) {
                reportedByMonth.put(m, cnt);
            }
        }

        for (AggregateResult ar : [
            SELECT CALENDAR_MONTH(Resolution_Date__c) m, COUNT(Id) cnt
            FROM Waste_Complaint__c
            WHERE Resolution_Date__c != null
            GROUP BY CALENDAR_MONTH(Resolution_Date__c)
        ]) {
            Integer m = (Integer)ar.get('m');
            Integer cnt = (Integer)ar.get('cnt');
            if (m != null) {
                resolvedByMonth.put(m, cnt);
            }
        }

        List<String> monthNames = new List<String>{
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        };

        for (Integer i = 1; i <= 12; i++) {
            trends.add(new MonthlyTrendItem(
                monthNames[i - 1],
                reportedByMonth.get(i),
                resolvedByMonth.get(i)
            ));
        }

        return trends;
    }

    /**
     * @description Returns SLA compliance breakdown
     */
    @AuraEnabled(cacheable=true)
    public static SLAComplianceData getSLAComplianceMetrics() {
        SLAComplianceData data = new SLAComplianceData();
        data.compliantCount = 0;
        data.breachedCount = 0;
        data.complianceRatePercent = 100.0;

        DateTime nowTime = DateTime.now();
        List<Waste_Complaint__c> allActive = [
            SELECT Id, SLA_Deadline__c, Status__c, Resolution_Date__c
            FROM Waste_Complaint__c
            WHERE SLA_Deadline__c != null
        ];

        for (Waste_Complaint__c wc : allActive) {
            if (wc.Status__c == 'Resolved' && wc.Resolution_Date__c != null) {
                if (wc.Resolution_Date__c <= wc.SLA_Deadline__c) {
                    data.compliantCount++;
                } else {
                    data.breachedCount++;
                }
            } else if (wc.Status__c != 'Rejected') {
                if (nowTime <= wc.SLA_Deadline__c) {
                    data.compliantCount++;
                } else {
                    data.breachedCount++;
                }
            }
        }

        Integer total = data.compliantCount + data.breachedCount;
        if (total > 0) {
            data.complianceRatePercent = ((Decimal)data.compliantCount / total * 100).setScale(1);
        }

        return data;
    }

    /**
     * @description Queries team workload and performance
     */
    @AuraEnabled(cacheable=true)
    public static List<Collection_Team__c> getTeamPerformance() {
        return [
            SELECT Id, Name, Team_Code__c, Team_Leader__c, Assigned_Area__c,
                   Availability_Status__c, Total_Assigned_Complaints__c
            FROM Collection_Team__c
            WHERE Active_Status__c = true
            ORDER BY Total_Assigned_Complaints__c DESC
            LIMIT 25
        ];
    }

    /**
     * @description Hotspot monitoring records for map and hotspot matrix
     */
    @AuraEnabled(cacheable=true)
    public static List<Waste_Location__c> getWasteHotspots() {
        return [
            SELECT Id, Name, Area__c, Address__c, Latitude__c, Longitude__c,
                   Waste_Category__c, Risk_Level__c, Active_Complaint_Count__c
            FROM Waste_Location__c
            ORDER BY Active_Complaint_Count__c DESC NULLS LAST
            LIMIT 50
        ];
    }

    /**
     * @description Flexible query for Complaint table with filters
     */
    @AuraEnabled(cacheable=true)
    public static List<Waste_Complaint__c> getComplaints(String statusFilter, String severityFilter, String searchKey) {
        String query = 'SELECT Id, Name, Complaint_Title__c, Waste_Type__c, Severity__c, Status__c, ' +
                       'Area__c, Street_Address__c, Reported_Date__c, SLA_Deadline__c, ' +
                       'Is_Escalated__c, Assigned_Team__r.Name, Assigned_Worker__r.Name, ' +
                       'Resolution_Notes__c, Resolution_Date__c, Resident_Email__c, Resident_Phone__c ' +
                       'FROM Waste_Complaint__c WHERE Id != null ';

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            query += ' AND Status__c = :statusFilter ';
        }

        if (String.isNotBlank(severityFilter) && severityFilter != 'All') {
            query += ' AND Severity__c = :severityFilter ';
        }

        if (String.isNotBlank(searchKey)) {
            String likeKey = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            query += ' AND (Name LIKE :likeKey OR Complaint_Title__c LIKE :likeKey OR Area__c LIKE :likeKey OR Street_Address__c LIKE :likeKey) ';
        }

        query += ' ORDER BY Reported_Date__c DESC NULLS LAST LIMIT 200';

        return Database.query(query);
    }
}
