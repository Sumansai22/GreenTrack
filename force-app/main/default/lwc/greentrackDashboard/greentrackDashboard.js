import { LightningElement, track } from 'lwc';

export default class GreentrackDashboard extends LightningElement {
    @track activeTab = 'overview';
    @track selectedComplaintId = null;

    handleNewComplaintClick() {
        this.activeTab = 'new_report';
    }

    handleNavigate(event) {
        if (event.detail && event.detail.tab) {
            this.activeTab = event.detail.tab;
        }
    }

    handleSelectComplaint(event) {
        this.selectedComplaintId = event.detail.complaintId;
    }

    handleComplaintSubmitted(event) {
        this.selectedComplaintId = event.detail.complaintId;
        this.activeTab = 'complaints';
    }

    handleComplaintUpdated() {
        const listComp = this.template.querySelector('c-complaint-list');
        if (listComp && typeof listComp.refreshData === 'function') {
            listComp.refreshData();
        }
    }
}
