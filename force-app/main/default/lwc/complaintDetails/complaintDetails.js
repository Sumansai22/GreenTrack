import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ComplaintDetails extends LightningElement {
    @api complaintId;

    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg', '.heic'];
    }

    handleSuccess(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Complaint record updated successfully.',
            variant: 'success'
        }));

        this.dispatchEvent(new CustomEvent('complaintupdated', {
            detail: { complaintId: this.complaintId }
        }));
    }

    handleError(event) {
        const errorMsg = (event.detail && event.detail.message) ? event.detail.message : 'Please check required fields.';
        this.dispatchEvent(new ShowToastEvent({
            title: 'Update Error',
            message: errorMsg,
            variant: 'error'
        }));
    }

    handleUploadFinished() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'File Uploaded',
            message: 'Photograph uploaded and linked to complaint.',
            variant: 'success'
        }));
    }
}
