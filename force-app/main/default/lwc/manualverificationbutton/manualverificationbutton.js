import { LightningElement, api } from 'lwc';
import processApplicationFromLWC from '@salesforce/apex/ApplicationVerificationGateway.processApplicationFromLWC';

export default class ManualVerificationButton extends LightningElement {
    @api recordId;
    isLoading = false;
    message = '';

    handleClick() {
        this.isLoading = true;
        this.message = '';

        processApplicationFromLWC({ applicationId: this.recordId })
            .then(() => {
                this.message = 'Verification successfully triggered.';
            })
            .catch(error => {
                this.message = 'Failed to trigger verification: ' + error.body.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}