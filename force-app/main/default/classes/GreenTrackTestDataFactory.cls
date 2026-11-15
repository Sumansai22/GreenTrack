/**
 * @description Centralized Test Data Factory for GreenTrack unit tests.
 */
@IsTest
public class GreenTrackTestDataFactory {
    
    public static Collection_Team__c createTeam(String name, String code, String area) {
        Collection_Team__c team = new Collection_Team__c(
            Name = name,
            Team_Code__c = code,
            Team_Leader__c = 'Leader ' + name,
            Contact_Number__c = '555-0199',
            Email__c = 'team.' + code.toLowerCase() + '@greentrack.org',
            Assigned_Area__c = area,
            Availability_Status__c = 'Available',
            Active_Status__c = true,
            Total_Assigned_Complaints__c = 0
        );
        insert team;
        return team;
    }

    public static Cleaning_Worker__c createWorker(String name, String empId, Id teamId, String area) {
        Cleaning_Worker__c worker = new Cleaning_Worker__c(
            Name = name,
            Employee_ID__c = empId,
            Contact_Number__c = '555-0188',
            Assigned_Team__c = teamId,
            Assigned_Area__c = area,
            Availability_Status__c = 'Available',
            Active_Status__c = true
        );
        insert worker;
        return worker;
    }

    public static Waste_Complaint__c buildComplaint(String title, String wasteType, String severity, String area) {
        return new Waste_Complaint__c(
            Complaint_Title__c = title,
            Description__c = 'Detailed description for ' + title,
            Waste_Type__c = wasteType,
            Severity__c = severity,
            Status__c = 'New',
            Area__c = area,
            Street_Address__c = '100 Green Ave, ' + area,
            City__c = 'EcoCity',
            Postal_Code__c = '94016',
            Resident_Email__c = 'resident.test@greentrack.org',
            Resident_Phone__c = '555-0123'
        );
    }

    public static Waste_Complaint__c createComplaint(String title, String wasteType, String severity, String area) {
        Waste_Complaint__c wc = buildComplaint(title, wasteType, severity, area);
        insert wc;
        return wc;
    }

    public static Recycling_Request__c createRecyclingRequest(String residentName, String category, Decimal quantity, Date pickupDate) {
        Recycling_Request__c req = new Recycling_Request__c(
            Resident_Name__c = residentName,
            Resident_Email__c = 'recycle.' + residentName.deleteWhitespace().toLowerCase() + '@example.com',
            Resident_Phone__c = '555-0144',
            Waste_Category__c = category,
            Estimated_Quantity__c = quantity,
            Pickup_Address__c = '789 Pine Rd',
            Pickup_Date__c = pickupDate,
            Status__c = 'Submitted'
        );
        insert req;
        return req;
    }

    public static Waste_Location__c createLocation(String name, String area, String riskLevel) {
        Waste_Location__c loc = new Waste_Location__c(
            Name = name,
            Area__c = area,
            Address__c = '55 Sector Blvd',
            Waste_Category__c = 'Mixed Waste',
            Risk_Level__c = riskLevel,
            Active_Complaint_Count__c = 3
        );
        insert loc;
        return loc;
    }

    public static User createTestUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueKey = String.valueOf(System.currentTimeMillis()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            FirstName = 'Test',
            LastName = 'User_' + alias,
            Email = alias + '_' + uniqueKey + '@greentracktest.org',
            Username = alias + '_' + uniqueKey + '@greentracktest.org',
            Alias = (alias.length() > 8) ? alias.substring(0, 8) : alias,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    public static Collection_Team__c createTeamWithLeaderUser(String name, String code, String area, Id leaderUserId) {
        Collection_Team__c team = new Collection_Team__c(
            Name = name,
            Team_Code__c = code,
            Team_Leader__c = 'Leader ' + name,
            Team_Leader_User__c = leaderUserId,
            Contact_Number__c = '555-0199',
            Email__c = 'team.' + code.toLowerCase() + '@greentrack.org',
            Assigned_Area__c = area,
            Availability_Status__c = 'Available',
            Active_Status__c = true,
            Total_Assigned_Complaints__c = 0
        );
        insert team;
        return team;
    }

    public static Cleaning_Worker__c createWorkerWithUser(String name, String empId, Id teamId, String area, Id workerUserId) {
        Cleaning_Worker__c worker = new Cleaning_Worker__c(
            Name = name,
            Employee_ID__c = empId,
            Worker_User__c = workerUserId,
            Contact_Number__c = '555-0188',
            Assigned_Team__c = teamId,
            Assigned_Area__c = area,
            Availability_Status__c = 'Available',
            Active_Status__c = true
        );
        insert worker;
        return worker;
    }
}
