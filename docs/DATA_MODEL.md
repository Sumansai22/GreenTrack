# GreenTrack Data Model & Entity-Relationship Architecture

## 1. Entity-Relationship Overview

```mermaid
erDiagram
    COLLECTION_TEAM ||--o{ CLEANING_WORKER : "employs (Assigned_Team__c)"
    COLLECTION_TEAM ||--o{ WASTE_COMPLAINT : "dispatched to (Assigned_Team__c)"
    CLEANING_WORKER ||--o{ WASTE_COMPLAINT : "actioned by (Assigned_Worker__c)"
    COLLECTION_TEAM ||--o{ RECYCLING_REQUEST : "collected by (Assigned_Team__c)"
    
    WASTE_COMPLAINT {
        string Name "WC-00001 (AutoNumber)"
        string Complaint_Title__c "Required Text"
        string Waste_Type__c "Picklist"
        string Severity__c "Picklist (Low, Med, High, Crit)"
        string Priority__c "Picklist (Low, Med, High, Urgent)"
        string Status__c "Picklist (New, Assigned, In Progress, Resolved...)"
        string Area__c "Municipal Zone"
        datetime Reported_Date__c "Timestamp"
        datetime SLA_Deadline__c "Calculated SLA"
        datetime Resolution_Date__c "Completion Timestamp"
        string Resolution_Notes__c "Required on Close"
        boolean Is_Escalated__c "Auto/Manual Flag"
        string Resident_Email__c "Contact"
    }

    COLLECTION_TEAM {
        string Name "Team Name"
        string Team_Code__c "Unique Code"
        string Team_Leader__c "Lead Supervisor"
        string Assigned_Area__c "Operating Zone"
        string Availability_Status__c "Available, Busy, Off"
        boolean Active_Status__c "Active"
        number Total_Assigned_Complaints__c "Active Workload"
    }

    CLEANING_WORKER {
        string Name "Worker Name"
        string Employee_ID__c "Unique ID"
        string Assigned_Team__c "Lookup Collection_Team__c"
        string Assigned_Area__c "Operational Zone"
        string Availability_Status__c "Available, On Assignment"
        boolean Active_Status__c "Active"
    }

    RECYCLING_REQUEST {
        string Name "RR-00001 (AutoNumber)"
        string Resident_Name__c "Resident"
        string Waste_Category__c "Plastics, Paper, Metals..."
        number Estimated_Quantity__c "Weight in kg"
        date Pickup_Date__c "Scheduled Date"
        string Status__c "Submitted, Scheduled, Completed"
        string Assigned_Team__c "Lookup Collection_Team__c"
        datetime Completion_Date__c "Timestamp"
    }

    WASTE_LOCATION {
        string Name "Hotspot Name"
        string Area__c "Zone"
        string Address__c "Street Details"
        number Latitude__c "GPS Latitude"
        number Longitude__c "GPS Longitude"
        string Waste_Category__c "Dumping Profile"
        string Risk_Level__c "Low, Med, High, Extreme"
        number Active_Complaint_Count__c "Density Tracker"
    }

    GREENTRACK_SLA_SETTING {
        string Target_Severity__c "Critical, High, Med, Low"
        number SLA_Hours__c "Target Turnaround Hours"
        boolean Auto_Escalate__c "Escalation Flag"
    }
```

## 2. Object Dictionary & Relationships

### A. Waste Complaint (`Waste_Complaint__c`)
* **Primary Key**: `Name` (Auto Number: `WC-{00000}`)
* **Assigned Team**: Lookup relationship to `Collection_Team__c`. Enables municipal routing and workload rollup.
* **Assigned Worker**: Lookup relationship to `Cleaning_Worker__c`. Enables field accountability and task attribution.
* **Audit & SLAs**: `Reported_Date__c`, `SLA_Deadline__c`, `Resolution_Date__c`, `Is_Escalated__c`.

### B. Collection Team (`Collection_Team__c`)
* **Primary Key**: `Name` (Text)
* **Unique External Identifier**: `Team_Code__c`
* **Workload Tracker**: `Total_Assigned_Complaints__c` tracks open non-resolved complaints automatically via Apex trigger handlers to prevent overloading.

### C. Cleaning Worker (`Cleaning_Worker__c`)
* **Primary Key**: `Name` (Text)
* **Unique External Identifier**: `Employee_ID__c`
* **Team Membership**: Lookup to `Collection_Team__c`.

### D. Recycling Request (`Recycling_Request__c`)
* **Primary Key**: `Name` (Auto Number: `RR-{00000}`)
* **Assigned Team**: Lookup to `Collection_Team__c` for bulk collection scheduling.

### E. Waste Location (`Waste_Location__c`)
* Monitors chronic dumping locations, public community bin overflow points, and GPS mapping coordinates.

### F. GreenTrack SLA Setting (`GreenTrack_SLA_Setting__mdt`)
* Configurable metadata driving SLA turnaround hours (Critical: 6h, High: 24h, Medium: 48h, Low: 72h) without hardcoded code values.
