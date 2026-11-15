import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkPotentialDuplicates from '@salesforce/apex/WasteComplaintDuplicateService.checkPotentialDuplicates';

export default class ComplaintRegistration extends LightningElement {
    @track latitude = null;
    @track longitude = null;
    @track area = '';
    @track wasteType = '';
    @track complaintTitle = '';
    @track duplicateWarning = false;
    @track duplicateComplaintName = '';
    @track isSubmitting = false;
    @track createdRecordId = null;

    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg', '.heic'];
    }

    handleTitleChange(event) {
        this.complaintTitle = event.target.value;
    }

    handleWasteTypeChange(event) {
        this.wasteType = event.target.value;
        this.checkForDuplicates();
    }

    handleAreaChange(event) {
        this.area = event.target.value;
        this.checkForDuplicates();
    }

    checkForDuplicates() {
        if (this.area && this.wasteType) {
            checkPotentialDuplicates({ area: this.area, wasteType: this.wasteType, streetAddress: '' })
                .then(result => {
                    if (result && result.length > 0) {
                        this.duplicateWarning = true;
                        this.duplicateComplaintName = result[0].Name + ' (' + result[0].Complaint_Title__c + ')';
                    } else {
                        this.duplicateWarning = false;
                    }
                })
                .catch(() => {
                    this.duplicateWarning = false;
                });
        }
    }

    handleGetLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.latitude = Number(position.coords.latitude.toFixed(6));
                    this.longitude = Number(position.coords.longitude.toFixed(6));
                    this.showToast('Location Captured', 'GPS coordinates added successfully', 'success');
                },
                (error) => {
                    this.showToast('Location Error', 'Unable to retrieve location: ' + error.message, 'warning');
                }
            );
        } else {
            this.showToast('Not Supported', 'Geolocation is not supported by your browser', 'info');
        }
    }

    handleSubmit(event) {
        this.isSubmitting = true;
    }

    handleSuccess(event) {
        this.isSubmitting = false;
        this.createdRecordId = event.detail.id;
        this.showToast('Success', 'Waste complaint submitted successfully! You may now attach photos.', 'success');

        this.dispatchEvent(new CustomEvent('complaintsubmitted', {
            detail: { complaintId: this.createdRecordId }
        }));
    }

    handleError(event) {
        this.isSubmitting = false;
        const msg = (event.detail && event.detail.message) ? event.detail.message : 'Please check required fields.';
        this.showToast('Submission Error', msg, 'error');
    }

    handleUploadFinished() {
        this.showToast('Photo Uploaded', 'Photographs attached to complaint successfully.', 'success');
    }

    handleReset() {
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        if (inputFields) {
            inputFields.forEach(field => {
                field.reset();
            });
        }
        this.duplicateWarning = false;
        this.latitude = null;
        this.longitude = null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
