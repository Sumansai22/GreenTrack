import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import createRecyclingRequest from '@salesforce/apex/RecyclingRequestService.createRecyclingRequest';
import completeRecyclingRequest from '@salesforce/apex/RecyclingRequestService.completeRecyclingRequest';
import getRecyclingRequests from '@salesforce/apex/RecyclingRequestService.getRecyclingRequests';

export default class RecyclingManagement extends LightningElement {
    @track requests = [];
    @track residentName = '';
    @track residentEmail = '';
    @track residentPhone = '';
    @track wasteCategory = 'Plastics';
    @track estimatedQty = 10;
    @track pickupDate = '';
    @track pickupAddress = '';

    wiredRequestsResult;

    get minDate() {
        return new Date().toISOString().split('T')[0];
    }

    get categoryOptions() {
        return [
            { label: 'Paper & Cardboard', value: 'Paper & Cardboard' },
            { label: 'Plastics', value: 'Plastics' },
            { label: 'Glass', value: 'Glass' },
            { label: 'Metals', value: 'Metals' },
            { label: 'Electronic E-Waste', value: 'Electronic E-Waste' },
            { label: 'Organic Compostable', value: 'Organic Compostable' }
        ];
    }

    get hasRequests() {
        return this.requests && this.requests.length > 0;
    }

    @wire(getRecyclingRequests, { statusFilter: 'All' })
    wiredRequests(result) {
        this.wiredRequestsResult = result;
        const { data, error } = result;
        if (data) {
            this.requests = data.map(r => ({
                ...r,
                isCompleted: r.Status__c === 'Completed'
            }));
        } else if (error) {
            this.requests = [];
        }
    }

    handleNameChange(e) { this.residentName = e.target.value; }
    handleEmailChange(e) { this.residentEmail = e.target.value; }
    handlePhoneChange(e) { this.residentPhone = e.target.value; }
    handleCategoryChange(e) { this.wasteCategory = e.target.value; }
    handleQtyChange(e) { this.estimatedQty = parseFloat(e.target.value); }
    handleDateChange(e) { this.pickupDate = e.target.value; }
    handleAddressChange(e) { this.pickupAddress = e.target.value; }

    handleBookPickup() {
        if (!this.residentName || !this.pickupDate || !this.pickupAddress) {
            this.showToast('Validation Error', 'Please complete Resident Name, Pickup Date, and Address.', 'error');
            return;
        }

        const newReq = {
            Resident_Name__c: this.residentName,
            Resident_Email__c: this.residentEmail,
            Resident_Phone__c: this.residentPhone,
            Waste_Category__c: this.wasteCategory,
            Estimated_Quantity__c: this.estimatedQty,
            Pickup_Date__c: this.pickupDate,
            Pickup_Address__c: this.pickupAddress,
            Status__c: 'Submitted'
        };

        createRecyclingRequest({ request: newReq })
            .then(() => {
                this.showToast('Success', 'Recycling pickup scheduled successfully!', 'success');
                this.residentName = '';
                this.residentEmail = '';
                this.residentPhone = '';
                this.pickupAddress = '';
                return refreshApex(this.wiredRequestsResult);
            })
            .catch(error => {
                const msg = error.body && error.body.message ? error.body.message : 'Failed to schedule pickup.';
                this.showToast('Booking Error', msg, 'error');
            });
    }

    handleCompletePickup(event) {
        const reqId = event.target.dataset.id;
        completeRecyclingRequest({ requestId: reqId })
            .then(() => {
                this.showToast('Updated', 'Recycling pickup marked as Completed.', 'success');
                return refreshApex(this.wiredRequestsResult);
            })
            .catch(error => {
                const msg = error.body && error.body.message ? error.body.message : 'Error updating status.';
                this.showToast('Error', msg, 'error');
            });
    }

    refreshList() {
        return refreshApex(this.wiredRequestsResult);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
