import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getTeamPerformance from '@salesforce/apex/WasteAnalyticsService.getTeamPerformance';
import getAvailableTeams from '@salesforce/apex/WasteAssignmentService.getAvailableTeams';
import getWorkersByTeam from '@salesforce/apex/WasteAssignmentService.getWorkersByTeam';
import assignComplaintManually from '@salesforce/apex/WasteAssignmentService.assignComplaintManually';
import getComplaints from '@salesforce/apex/WasteAnalyticsService.getComplaints';

export default class TeamAssignment extends LightningElement {
    @track teams = [];
    @track complaintOptions = [];
    @track teamOptions = [];
    @track workerOptions = [];

    @track selectedComplaintId = null;
    @track selectedTeamId = null;
    @track selectedWorkerId = null;

    wiredTeamsResult;

    get hasTeams() {
        return this.teams && this.teams.length > 0;
    }

    get isWorkerDisabled() {
        return !this.selectedTeamId || this.workerOptions.length === 0;
    }

    get isDispatchDisabled() {
        return !this.selectedComplaintId || !this.selectedTeamId;
    }

    @wire(getTeamPerformance)
    wiredTeams(result) {
        this.wiredTeamsResult = result;
        const { data, error } = result;
        if (data) {
            this.teams = data;
            this.teamOptions = data.map(t => ({
                label: `${t.Name} (${t.Assigned_Area__c || 'All'} - ${t.Total_Assigned_Complaints__c || 0} active)`,
                value: t.Id
            }));
        } else if (error) {
            this.teams = [];
            this.teamOptions = [];
        }
    }

    @wire(getComplaints, { statusFilter: 'All', severityFilter: 'All', searchKey: '' })
    wiredComplaints({ data, error }) {
        if (data) {
            this.complaintOptions = data
                .filter(c => c.Status__c !== 'Resolved' && c.Status__c !== 'Rejected')
                .map(c => ({
                    label: `${c.Name} - ${c.Complaint_Title__c} [${c.Severity__c}]`,
                    value: c.Id
                }));
        }
    }

    handleComplaintChange(event) {
        this.selectedComplaintId = event.target.value;
    }

    handleTeamChange(event) {
        this.selectedTeamId = event.target.value;
        this.selectedWorkerId = null;
        this.loadWorkersForTeam(this.selectedTeamId);
    }

    handleWorkerChange(event) {
        this.selectedWorkerId = event.target.value;
    }

    loadWorkersForTeam(teamId) {
        getWorkersByTeam({ teamId: teamId })
            .then(workers => {
                this.workerOptions = workers.map(w => ({
                    label: `${w.Name} (${w.Employee_ID__c || 'N/A'})`,
                    value: w.Id
                }));
            })
            .catch(() => {
                this.workerOptions = [];
            });
    }

    handleDispatch() {
        if (!this.selectedComplaintId || !this.selectedTeamId) {
            return;
        }

        assignComplaintManually({
            complaintId: this.selectedComplaintId,
            teamId: this.selectedTeamId,
            workerId: this.selectedWorkerId
        })
            .then(() => {
                this.showToast('Success', 'Complaint successfully dispatched to collection team.', 'success');
                this.selectedComplaintId = null;
                this.selectedTeamId = null;
                this.selectedWorkerId = null;
                return refreshApex(this.wiredTeamsResult);
            })
            .catch(error => {
                const msg = error.body && error.body.message ? error.body.message : 'Failed to assign team.';
                this.showToast('Dispatch Error', msg, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
