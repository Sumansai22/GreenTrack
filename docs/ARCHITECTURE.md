# GreenTrack Architecture & Automation Ownership

## 1. Automation Architecture & Separation of Concerns

To prevent recursive loops, governor limits, and duplicate logic, GreenTrack establishes clear ownership between Apex and Flows:

| Capability / Requirement | Owning Component | Logic Detail |
|---|---|---|
| **SLA & Priority Calculation** | `SLAService.cls` (Apex) | Calculates SLA deadline and priority from `GreenTrack_SLA_Setting__mdt` on record creation and severity update. |
| **Duplicate Complaint Flagging** | `WasteComplaintDuplicateService.cls` (Apex) | Queries 48-hour active complaints matching `Area__c` and `Waste_Type__c`. Real-time LWC warning + trigger tag. |
| **Intelligent Routing & Workload** | `WasteAssignmentService.cls` (Apex) | Matches available teams in area with lowest current active load; updates `Total_Assigned_Complaints__c`. |
| **Trigger Orchestration** | `WasteComplaintTriggerHandler.cls` (Apex) | Single trigger per object pattern; static boolean `isTriggerExecuting` prevents recursion. |
| **Resident & Admin Notifications** | `NotificationService.cls` (Apex) | Deduplicated alert dispatch and audit Task generation for submission, assignment, resolution, and escalation. |
| **Default Complaint Status** | `Complaint_Submission_Flow.flow-meta.xml` (Flow) | Fast before-save assignment ensuring initial submitted status. |
| **Overdue Auto-Escalation** | `SLA_Monitoring_Flow.flow-meta.xml` (Flow) | Evaluates critical/overdue complaints and triggers escalation status. |
| **Completion Stamping** | `Complaint_Resolution_Flow.flow-meta.xml` (Flow) | Enforces resolution timestamping on closed complaints. |
| **Bulk Recycling Routing** | `RecyclingRequestService.cls` (Apex) & Flow | Validates pickup dates, allocates vehicle teams, and tracks recycling kg diverted. |

## 2. Apex Design Standards Applied

1. **Trigger-Handler Architecture**: All business logic lives in domain service classes (`SLAService`, `WasteAssignmentService`, `NotificationService`).
2. **Bulkification**: All SOQL queries and DML statements operate on Collections outside of loops.
3. **Least Privilege Security**: All Apex classes are declared `with sharing`.
4. **Metadata-Driven Configuration**: SLA thresholds are managed in Custom Metadata rather than hardcoded IDs or constants.
5. **Real Database Metrics**: `WasteAnalyticsService` provides real-time aggregated metrics directly from SOQL without simulated numbers.
