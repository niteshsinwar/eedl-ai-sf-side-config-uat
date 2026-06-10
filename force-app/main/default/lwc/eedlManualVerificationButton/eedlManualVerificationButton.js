import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import processOpportunityFromLWC from '@salesforce/apex/EEDLVerificationGateway.processOpportunityFromLWC';

export default class EedlManualVerificationButton extends LightningElement {
    @api recordId;
    isLoading = false;

    async handleClick() {
        this.isLoading = true;
        try {
            await processOpportunityFromLWC({ opportunityId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'EEDL verification queued',
                    message: 'The opportunity has been submitted for EEDL verification.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to start EEDL verification',
                    message: error?.body?.message || error?.message || 'Unknown error',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}