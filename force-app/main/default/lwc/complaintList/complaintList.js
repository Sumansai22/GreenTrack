import { LightningElement, track, wire, api } from 'lwc';
import getComplaints from '@salesforce/apex/WasteAnalyticsService.getComplaints';
import { refreshApex } from '@salesforce/apex';

export default class ComplaintList extends LightningElement {
    @track complaints = [];
    @track searchKey = '';
    @track statusFilter = 'All';
    @track severityFilter = 'All';
    wiredComplaintsResult;

    get statusOptions() {
        return [
            { label: 'All Statuses', value: 'All' },
            { label: 'New', value: 'New' },
            { label: 'Submitted', value: 'Submitted' },
            { label: 'Assigned', value: 'Assigned' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Resolved', value: 'Resolved' },
            { label: 'Rejected', value: 'Rejected' },
            { label: 'Reopened', value: 'Reopened' }
        ];
    }

    get severityOptions() {
        return [
            { label: 'All Severities', value: 'All' },
            { label: 'Critical', value: 'Critical' },
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    get hasComplaints() {
        return this.complaints && this.complaints.length > 0;
    }

    @wire(getComplaints, { statusFilter: '$statusFilter', severityFilter: '$severityFilter', searchKey: '$searchKey' })
    wiredComplaints(result) {
        this.wiredComplaintsResult = result;
        const { data, error } = result;
        if (data) {
            this.complaints = data.map(item => {
                let badgeClass = 'slds-badge ';
                if (item.Severity__c === 'Critical') {
                    badgeClass += 'gt-badge-critical';
                } else if (item.Severity__c === 'High') {
                    badgeClass += 'gt-badge-high';
                } else if (item.Severity__c === 'Medium') {
                    badgeClass += 'gt-badge-medium';
                } else {
                    badgeClass += 'gt-badge-low';
                }

                return {
                    ...item,
                    severityBadgeClass: badgeClass,
                    teamName: item.Assigned_Team__r ? item.Assigned_Team__r.Name : 'Unassigned'
                };
            });
        } else if (error) {
            this.complaints = [];
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.target.value;
    }

    handleSeverityFilterChange(event) {
        this.severityFilter = event.target.value;
    }

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        this.dispatchSelectEvent(id);
    }

    handleViewClick(event) {
        event.stopPropagation();
        const id = event.target.dataset.id;
        this.dispatchSelectEvent(id);
    }

    dispatchSelectEvent(complaintId) {
        this.dispatchEvent(new CustomEvent('selectcomplaint', {
            detail: { complaintId: complaintId }
        }));
    }

    @api
    refreshData() {
        return refreshApex(this.wiredComplaintsResult);
    }
}
