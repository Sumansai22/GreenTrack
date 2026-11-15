# GreenTrack – Smart Waste Management & Sustainability Platform
## Academic Capstone Project – Salesforce Individual Implementation

GreenTrack is a comprehensive, production-grade Salesforce platform engineered for municipal administrations and urban communities. It modernizes waste management operations, illegal dumping monitoring, doorstep recycling coordination, and field team dispatch with real-time analytics and automated SLA enforcement.

---

## 🌟 Key Functional Pillars

1. **Resident Self-Service Complaints Portal**:
   - Geolocation-assisted waste complaint reporting.
   - Real-time duplicate detection warning before ticket creation.
   - Photograph and file evidence attachments via Salesforce Files.

2. **Intelligent Dispatch & Team Workload Balancing**:
   - Automatic routing of tickets based on municipal area and team capacity.
   - Real-time tracking of active complaint workloads across collection teams.
   - Drag-and-drop manual re-assignment and field worker tasking.

3. **Configurable SLA Enforcement & Escalation**:
   - Turnaround targets powered by `GreenTrack_SLA_Setting__mdt` Custom Metadata.
   - Automated priority mapping (Critical, High, Medium, Low).
   - Automated escalation of overdue tickets and critical hazardous waste.

4. **Doorstep Bulk Recycling Coordination**:
   - Scheduled residential pickups for plastics, glass, paper, e-waste, and organics.
   - Live metrics calculating total kilograms of waste diverted from landfills.

5. **Geospatial Hotspot Risk Matrix**:
   - Interactive `lightning-map` plotting recurring dumping sites, coordinates, and risk severity.

6. **Executive Analytics & Reports**:
   - 10 real-time KPI metrics, monthly trend analysis, and SLA compliance calculations querying live Salesforce records.

---

## 📂 Salesforce DX Project Architecture

```
greentrack/
├── force-app/
│   └── main/
│       └── default/
│           ├── applications/
│           │   └── GreenTrack.app-meta.xml
│           ├── classes/
│           │   ├── GreenTrackTestDataFactory.cls
│           │   ├── NotificationService.cls
│           │   ├── NotificationServiceTest.cls
│           │   ├── RecyclingRequestService.cls
│           │   ├── RecyclingRequestServiceTest.cls
│           │   ├── SLAService.cls
│           │   ├── SLAServiceTest.cls
│           │   ├── WasteAnalyticsService.cls
│           │   ├── WasteAnalyticsServiceTest.cls
│           │   ├── WasteAssignmentService.cls
│           │   ├── WasteAssignmentServiceTest.cls
│           │   ├── WasteComplaintDuplicateService.cls
│           │   ├── WasteComplaintDuplicateServiceTest.cls
│           │   ├── WasteComplaintTriggerHandler.cls
│           │   └── WasteComplaintTriggerTest.cls
│           ├── customMetadata/
│           │   ├── GreenTrack_SLA_Setting.Critical.md-meta.xml
│           │   ├── GreenTrack_SLA_Setting.High.md-meta.xml
│           │   ├── GreenTrack_SLA_Setting.Medium.md-meta.xml
│           │   └── GreenTrack_SLA_Setting.Low.md-meta.xml
│           ├── dashboards/
│           │   ├── GreenTrack_Dashboards-meta.xml
│           │   └── GreenTrack_Dashboards/GreenTrack_Executive_Dashboard.dashboard-meta.xml
│           ├── flexipages/
│           │   └── GreenTrack_Hub_Page.flexipage-meta.xml
│           ├── flows/
│           │   ├── Automatic_Team_Assignment_Flow.flow-meta.xml
│           │   ├── Complaint_Resolution_Flow.flow-meta.xml
│           │   ├── Complaint_Submission_Flow.flow-meta.xml
│           │   ├── Recycling_Request_Flow.flow-meta.xml
│           │   └── SLA_Monitoring_Flow.flow-meta.xml
│           ├── lwc/
│           │   ├── adminOverview/
│           │   ├── complaintDetails/
│           │   ├── complaintList/
│           │   ├── complaintRegistration/
│           │   ├── greentrackDashboard/
│           │   ├── recyclingManagement/
│           │   ├── sustainabilityAnalytics/
│           │   ├── teamAssignment/
│           │   ├── wasteHotspotDashboard/
│           │   └── workerManagement/
│           ├── objects/
│           │   ├── Cleaning_Worker__c/
│           │   ├── Collection_Team__c/
│           │   ├── GreenTrack_SLA_Setting__mdt/
│           │   ├── Recycling_Request__c/
│           │   ├── Waste_Complaint__c/
│           │   └── Waste_Location__c/
│           ├── permissionsets/
│           │   ├── GreenTrack_Cleaning_Worker.permissionset-meta.xml
│           │   ├── GreenTrack_Municipal_Admin.permissionset-meta.xml
│           │   ├── GreenTrack_Resident.permissionset-meta.xml
│           │   └── GreenTrack_Team_Leader.permissionset-meta.xml
│           ├── reports/
│           │   ├── GreenTrack_Reports-meta.xml
│           │   └── GreenTrack_Reports/
│           ├── tabs/
│           └── triggers/
│               └── WasteComplaintTrigger.trigger
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATA_MODEL.md
│   └── DEPLOYMENT_GUIDE.md
└── sfdx-project.json
```

---

## 🔒 Security & Access Control Matrix

| Role | Permissions | Objects Accessible |
|---|---|---|
| **Resident** | Submit & track complaints, book recycling, view hotspots | `Waste_Complaint__c` (Create/Read), `Recycling_Request__c` (Create/Read), `Waste_Location__c` (Read) |
| **Municipal Administrator** | Full platform management, dispatch, SLA monitor | Full CRUD & View All / Modify All on all objects |
| **Cleaning Team Leader** | Dispatch workers, update complaint status, resolve tickets | Read & Edit on assigned complaints, teams, workers |
| **Cleaning Worker** | View tasks, post field updates, add resolution notes | Read & Edit on assigned work tickets |

---

## 🚀 Deployment Instructions
See detailed deployment procedures in [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md).
