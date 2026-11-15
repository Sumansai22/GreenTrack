import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getWorkersByTeam from '@salesforce/apex/WasteAssignmentService.getWorkersByTeam';

export default class WorkerManagement extends LightningElement {
    @track workers = [];
    @track isModalOpen = false;
    wiredWorkersResult;

    workerFields = [
        'Name',
        'Employee_ID__c',
        'Contact_Number__c',
        'Assigned_Team__c',
        'Assigned_Area__c',
        'Availability_Status__c',
        'Active_Status__c'
    ];

    get hasWorkers() {
        return this.workers && this.workers.length > 0;
    }

    @wire(getWorkersByTeam, { teamId: null })
    wiredWorkers(result) {
        this.wiredWorkersResult = result;
        const { data, error } = result;
        if (data) {
            this.workers = data.map(w => ({
                ...w,
                teamName: w.Assigned_Team__r ? w.Assigned_Team__r.Name : 'Unassigned'
            }));
        } else if (error) {
            this.workers = [];
        }
    }

    handleNewWorker() {
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleWorkerCreated() {
        this.isModalOpen = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Worker Registered',
            message: 'Cleaning worker has been added successfully.',
            variant: 'success'
        }));
        return refreshApex(this.wiredWorkersResult);
    }
}
