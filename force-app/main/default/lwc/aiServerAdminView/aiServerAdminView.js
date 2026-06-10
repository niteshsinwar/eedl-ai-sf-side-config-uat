import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getHealthStatus from '@salesforce/apex/AIserverAdminViewController.getHealthStatus';
import getActiveJobs from '@salesforce/apex/AIserverAdminViewController.getActiveJobs';
import getConcludedJobs from '@salesforce/apex/AIserverAdminViewController.getConcludedJobs';
import getApiTransactions from '@salesforce/apex/AIserverAdminViewController.getApiTransactions';
import retryApplications from '@salesforce/apex/AIserverAdminViewController.retryApplications';
import deleteActiveJobs from '@salesforce/apex/AIserverAdminViewController.deleteActiveJobs';
import deleteConcludedJobs from '@salesforce/apex/AIserverAdminViewController.deleteConcludedJobs';
import deleteTransactions from '@salesforce/apex/AIserverAdminViewController.deleteTransactions';
import getJobDetail from '@salesforce/apex/AIserverAdminViewController.getJobDetail';
import getTotalJobCount from '@salesforce/apex/AIserverAdminViewController.getTotalJobCount';
import getJobLogs from '@salesforce/apex/AIserverAdminViewController.getJobLogs';

const CONCLUDED_STATUSES = ['completed', 'failed'];

export default class AiServerAdminView extends LightningElement {
    @track activeJobsColumns = [
        { label: 'Flow', fieldName: 'sourceRecordType', type: 'text', hideDefaultActions: true, initialWidth: 180 },
        { label: 'Source Record', fieldName: 'applicationUrl', type: 'url', typeAttributes: { label: { fieldName: 'applicationName' }, target: '_blank' }, hideDefaultActions: true, initialWidth: 300 },
        { label: 'Status', fieldName: 'status', type: 'text', cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'Progress', fieldName: 'progressSummary', type: 'text' },
        { label: 'Last Update', fieldName: 'last_updated_at', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
        { type: 'action', typeAttributes: { rowActions: this.getActiveJobActions.bind(this) } }
    ];
    @track concludedJobsColumns = [
        { label: 'Flow', fieldName: 'sourceRecordType', type: 'text', hideDefaultActions: true, initialWidth: 180 },
        { label: 'Source Record', fieldName: 'applicationUrl', type: 'url', typeAttributes: { label: { fieldName: 'applicationName' }, target: '_blank' }, hideDefaultActions: true, initialWidth: 300 },
        { label: 'Technical Status', fieldName: 'status', type: 'text', cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'Message', fieldName: 'message', type: 'text', wrapText: true },
        { label: 'Concluded At', fieldName: 'last_updated_at', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
        { type: 'action', typeAttributes: { rowActions: this.getConcludedJobActions.bind(this) } }
    ];
    @track succeededApiColumns = [
        { label: 'Flow', fieldName: 'sourceRecordType', type: 'text', hideDefaultActions: true, initialWidth: 180 },
        { label: 'Source Record', fieldName: 'applicationUrl', type: 'url', typeAttributes: { label: { fieldName: 'applicationName' }, target: '_blank' }, hideDefaultActions: true, initialWidth: 250 },
        { label: 'Logged At', fieldName: 'createdAt', type: 'date', sortable: true, typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit', timeZoneName: 'short' } },
        { label: 'Request', fieldName: 'request', type: 'text', wrapText: true },
        { label: 'Response / Error', fieldName: 'response', type: 'text', wrapText: true },
        { label: 'Error Message', fieldName: 'errorMessage', type: 'text', wrapText: true, initialWidth: 300 },
        { type: 'action', typeAttributes: { rowActions: this.getSucceededTransactionActions.bind(this) } }
    ];
    @track failedApiColumns = [
        { label: 'Flow', fieldName: 'sourceRecordType', type: 'text', hideDefaultActions: true, initialWidth: 180 },
        { label: 'Source Record', fieldName: 'applicationUrl', type: 'url', typeAttributes: { label: { fieldName: 'applicationName' }, target: '_blank' }, hideDefaultActions: true, initialWidth: 250 },
        { label: 'Logged At', fieldName: 'createdAt', type: 'date', sortable: true, typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit', timeZoneName: 'short' } },
        { label: 'Request', fieldName: 'request', type: 'text', wrapText: true },
        { label: 'Response / Error', fieldName: 'response', type: 'text', wrapText: true },
        { label: 'Error Message', fieldName: 'errorMessage', type: 'text', wrapText: true, initialWidth: 300 },
        { type: 'action', typeAttributes: { rowActions: this.getFailedTransactionActions.bind(this) } }
    ];

    @track healthData;
    @track activeJobs = [];
    @track concludedJobs = [];
    @track succeededApiLogs = [];
    @track failedApiLogs = [];
    @track selectedActiveJobs = [];
    @track selectedConcludedJobs = [];
    @track selectedSucceededTransactions = [];
    @track selectedFailedTransactions = [];
    @track error = {};
    @track modal = { show: false };
    @track showJobDetailModal = false;
    @track selectedJob;
    @track lastRefreshTime;
    @track healthStatusClass;
    @track isLoading = { health: true, jobs: true, transactions: true, logs: true };
    @track isJobDetailLoading = false;
    @track sortedBy = 'createdAt';
    @track sortDirection = 'desc';

    // Logs Analytics
    @track logsData = [];
    @track costAnalytics = { daily: 0, weekly: 0, monthly: 0, total: 0 };
    @track documentTypeStats = [];
    @track applicationExecutionHistory = [];
    @track selectedApplicationLogs = null;
    @track showExecutionHistoryModal = false;
    @track startDate = null;
    @track endDate = null;

    activeSections = ['progressing', 'concluded', 'succeeded_transactions', 'failed_transactions', 'cost_analytics', 'document_stats', 'execution_history'];
    autoRefreshEnabled = false;
    _autoRefreshTimer;
    _wiredActiveJobsResult;
    _wiredConcludedJobsResult;
    _wiredApiTransactionsResult;
    _wiredTotalJobsResult;
    _wiredJobLogsResult;

    @wire(getTotalJobCount) wiredTotalJobs(result) { this._wiredTotalJobsResult = result; }
    @wire(getActiveJobs) wiredActiveJobs(result) {
        this._wiredActiveJobsResult = result;
        if (result.data) {
            this.activeJobs = (result.data.all_jobs || []).map(j => ({ ...j, statusClass: this.getStatusClass(j.status), progressSummary: this.formatProgressSummary(this.parseProgress(j.progress), j.status) }));
            this.error.active = undefined;
        } else if (result.error) {
            this.error.active = this.reduceErrors(result.error);
        }
    }
    @wire(getConcludedJobs) wiredConcludedJobs(result) {
        this._wiredConcludedJobsResult = result;
        if (result.data) {
            this.concludedJobs = result.data.map(j => ({ ...j, statusClass: this.getStatusClass(j.status) }));
            this.error.concluded = undefined;
        } else if (result.error) {
            this.error.concluded = this.reduceErrors(result.error);
        }
    }
    @wire(getApiTransactions) wiredApiTransactions(result) {
        this._wiredApiTransactionsResult = result;
        if (result.data) {
            this.succeededApiLogs = result.data.succeededLogs;
            this.failedApiLogs = result.data.failedLogs;
            this.sortApiData(this.sortedBy, this.sortDirection);
            this.error.transactions = undefined;
        } else if (result.error) {
            this.error.transactions = this.reduceErrors(result.error);
        }
    }

    @wire(getJobLogs) wiredJobLogs(result) {
        this._wiredJobLogsResult = result;
        if (result.data) {
            this.logsData = result.data.logs || [];
            this.processLogsAnalytics();
            this.error.logs = undefined;
            this.isLoading.logs = false;
        } else if (result.error) {
            this.error.logs = this.reduceErrors(result.error);
            this.isLoading.logs = false;
        }
    }

    connectedCallback() { this.handleRefresh(); }
    disconnectedCallback() { this.stopAutoRefresh(); }

    handleRefresh() {
        this.isLoading.health = true;
        this.isLoading.jobs = true;
        this.isLoading.transactions = true;
        this.isLoading.logs = true;
        this.lastRefreshTime = new Date();
        this.showToast('Refreshing...', 'Fetching latest data from server and Salesforce.', 'info');
        getHealthStatus()
            .then(data => {
                const status = (data.status || '').toLowerCase();
                this.healthData = { ...data, checks: (data.checks || []).map(c => ({ ...c, icon: c.status.toLowerCase() === 'ok' ? 'utility:success' : 'utility:warning' })) };
                this.healthStatusClass = status === 'ok' ? 'slds-theme_success' : 'slds-theme_warning';
            })
            .catch(e => { this.error.health = this.reduceErrors(e); })
            .finally(() => { this.isLoading.health = false; });
        refreshApex(this._wiredActiveJobsResult).finally(() => this.isLoading.jobs = false);
        refreshApex(this._wiredConcludedJobsResult);
        refreshApex(this._wiredApiTransactionsResult).finally(() => this.isLoading.transactions = false);
        refreshApex(this._wiredJobLogsResult).finally(() => this.isLoading.logs = false);
        if (this._wiredTotalJobsResult) {
            refreshApex(this._wiredTotalJobsResult);
        }
    }

    toggleAutoRefresh() {
        this.autoRefreshEnabled = !this.autoRefreshEnabled;
        if (this.autoRefreshEnabled) this.startAutoRefresh();
        else this.stopAutoRefresh();
    }

    startAutoRefresh() {
        this.stopAutoRefresh();
        this.showToast('Auto Refresh ON', 'Panel will refresh every 10 seconds.', 'success');
        this._autoRefreshTimer = setInterval(() => {
            if (!this.modal.show && !this.showJobDetailModal && !this.showExecutionHistoryModal) {
                this.lastRefreshTime = new Date();
                refreshApex(this._wiredActiveJobsResult);
                refreshApex(this._wiredConcludedJobsResult);
                refreshApex(this._wiredApiTransactionsResult);
                refreshApex(this._wiredJobLogsResult);
                if (this._wiredTotalJobsResult) {
                    refreshApex(this._wiredTotalJobsResult);
                }
            }
        }, 10000);
    }

    stopAutoRefresh() {
        if (this._autoRefreshTimer) {
            clearInterval(this._autoRefreshTimer);
            this._autoRefreshTimer = null;
            this.showToast('Auto Refresh OFF', '', 'info');
        }
    }

    getActiveJobActions(row, done) {
        done([
            { label: 'View Details', name: 'view_details' },
            { label: 'Delete', name: 'delete_job' }
        ]);
    }

    getConcludedJobActions(row, done) {
        const actions = [
            { label: 'View Details', name: 'view_details' },
            { label: 'Delete', name: 'delete_job' }
        ];
        if (row.status.toLowerCase() === 'failed') {
            actions.push({ label: 'Retry', name: 'retry_job' });
        }
        done(actions);
    }

    getSucceededTransactionActions(row, done) {
        done([{ label: 'Delete', name: 'delete_transaction' }]);
    }

    getFailedTransactionActions(row, done) {
        done([
            { label: 'Delete', name: 'delete_transaction' },
            { label: 'Retry', name: 'retry_transaction' }
        ]);
    }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view_details') {
            this.viewJobDetails(row.application_id || row.applicationId);
        } else if (name === 'delete_job') {
            if (row.id) {
                this.showConfirmationModal('Confirm Delete Job', `Are you sure you want to delete this concluded job?`, 'Delete', () => this.executeDeleteConcludedJob(row.id));
            } else {
                this.showConfirmationModal('Confirm Delete Active Job', `Are you sure you want to delete this active job? It will be cleared from the server.`, 'Delete', () => this.executeDeleteActiveJob(row.application_id));
            }
        } else if (name === 'retry_job' || name === 'retry_transaction') {
            this.showConfirmationModal('Confirm Retry', `This will retry the verification for source record ID: ${row.application_id || row.applicationId}. Continue?`, 'Retry', () => this.executeRetryApplication(row.application_id || row.applicationId));
        } else if (name === 'delete_transaction') {
            this.showConfirmationModal('Confirm Delete Transaction', `Are you sure you want to delete this transaction log?`, 'Delete', () => this.executeDeleteTransaction(row.logId));
        }
    }

    handleActiveJobsSelection(event) {
        this.selectedActiveJobs = event.detail.selectedRows;
    }

    handleConcludedJobsSelection(event) {
        this.selectedConcludedJobs = event.detail.selectedRows;
    }

    handleSucceededTransactionsSelection(event) {
        this.selectedSucceededTransactions = event.detail.selectedRows;
    }

    handleFailedTransactionsSelection(event) {
        this.selectedFailedTransactions = event.detail.selectedRows;
    }

    async handleMassDeleteActiveJobs() {
        const applicationIds = this.selectedActiveJobs.map(job => job.application_id);
        this.showConfirmationModal('Confirm Mass Delete Active Jobs', `Are you sure you want to delete ${applicationIds.length} active jobs? They will be cleared from the server.`, 'Delete', async () => {
            try {
                await deleteActiveJobs({ applicationIds });
                this.showToast('Success', 'Active jobs deleted.', 'success');
                this.handleRefresh();
            } catch (e) {
                this.showToast('Error Deleting Active Jobs', e.body.message, 'error');
            }
        });
    }

    async handleMassDeleteConcludedJobs() {
        const jobIds = this.selectedConcludedJobs.map(job => job.id);
        this.showConfirmationModal('Confirm Mass Delete Concluded Jobs', `Are you sure you want to delete ${jobIds.length} concluded jobs?`, 'Delete', async () => {
            try {
                await deleteConcludedJobs({ jobIds });
                this.showToast('Success', 'Concluded jobs deleted.', 'success');
                this.handleRefresh();
            } catch (e) {
                this.showToast('Error Deleting Concluded Jobs', e.body.message, 'error');
            }
        });
    }

    async handleMassRetryConcludedJobs() {
        const failedJobs = this.retryableConcludedJobs;
        const applicationIds = failedJobs.map(job => job.application_id);
        this.showConfirmationModal('Confirm Mass Retry Jobs', `Are you sure you want to retry ${applicationIds.length} failed jobs?`, 'Retry', async () => {
            try {
                await retryApplications({ applicationIds });
                this.showToast('Success', `${applicationIds.length} verification retries enqueued.`, 'success');
                this.handleRefresh();
            } catch (e) {
                this.showToast('Error Retrying Jobs', e.body.message, 'error');
            }
        });
    }

    async handleMassDeleteSucceededTransactions() {
        const logIds = this.selectedSucceededTransactions.map(tx => tx.logId);
        this.showConfirmationModal('Confirm Mass Delete Succeeded Transactions', `Are you sure you want to delete ${logIds.length} succeeded transaction logs?`, 'Delete', async () => {
            try {
                await deleteTransactions({ logIds });
                this.showToast('Success', 'Succeeded transaction logs deleted.', 'success');
                this.handleRefresh();
            } catch (e) {
                this.showToast('Error Deleting Succeeded Transactions', e.body.message, 'error');
            }
        });
    }

    async handleMassDeleteFailedTransactions() {
        const logIds = this.selectedFailedTransactions.map(tx => tx.logId);
        this.showConfirmationModal('Confirm Mass Delete Failed Transactions', `Are you sure you want to delete ${logIds.length} failed transaction logs?`, 'Delete', async () => {
            try {
                await deleteTransactions({ logIds });
                this.showToast('Success', 'Failed transaction logs deleted.', 'success');
                this.handleRefresh();
            } catch (e) {
                this.showToast('Error Deleting Failed Transactions', e.body.message, 'error');
            }
        });
    }

    async handleMassRetryFailedTransactions() {
        const applicationIds = this.selectedFailedTransactions.map(tx => tx.applicationId).filter(id => id);
        if (applicationIds.length === 0) {
            this.showToast('No Selection', 'Please select one or more failed transactions to retry.', 'warning');
            return;
        }
        this.showConfirmationModal('Confirm Mass Retry Transactions', `Are you sure you want to retry ${applicationIds.length} failed transactions?`, 'Retry', async () => {
            try {
                await retryApplications({ applicationIds });
                this.showToast('Success', `${applicationIds.length} verification retries enqueued.`, 'success');
                this.handleRefresh();
            } catch (e) {
                this.showToast('Error Retrying Transactions', e.body.message, 'error');
            }
        });
    }

    async executeDeleteActiveJob(applicationId) {
        try {
            await deleteActiveJobs({ applicationIds: [applicationId] });
            this.showToast('Success', 'Active job deleted.', 'success');
            this.handleRefresh();
        } catch (e) {
            this.showToast('Error Deleting Active Job', e.body.message, 'error');
        }
    }

    async executeDeleteConcludedJob(jobId) {
        try {
            await deleteConcludedJobs({ jobIds: [jobId] });
            this.showToast('Success', 'Concluded job deleted.', 'success');
            this.handleRefresh();
        } catch (e) {
            this.showToast('Error Deleting Concluded Job', e.body.message, 'error');
        }
    }

    async executeDeleteTransaction(logId) {
        try {
            await deleteTransactions({ logIds: [logId] });
            this.showToast('Success', 'Transaction log deleted.', 'success');
            this.handleRefresh();
        } catch (e) {
            this.showToast('Error Deleting Transaction', e.body.message, 'error');
        }
    }

    async executeRetryApplication(applicationId) {
        try {
            await retryApplications({ applicationIds: [applicationId] });
            this.showToast('Success', 'Application verification retry enqueued.', 'success');
            this.handleRefresh();
        } catch (e) {
            this.showToast('Error Retrying Application', e.body.message, 'error');
        }
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortDirection = sortDirection;
        this.sortApiData(sortedBy, sortDirection);
    }

    sortApiData(fieldName, direction) {
        this.succeededApiLogs = this.sortArray([...this.succeededApiLogs], fieldName, direction);
        this.failedApiLogs = this.sortArray([...this.failedApiLogs], fieldName, direction);
    }

    sortArray(data, fieldName, direction) {
        const keyValue = (a) => a[fieldName] || '';
        const isReverse = direction === 'asc' ? 1 : -1;
        data.sort((x, y) => {
            const valX = keyValue(x);
            const valY = keyValue(y);
            return isReverse * ((valX > valY) - (valY > valX));
        });
        return data;
    }

    async viewJobDetails(applicationId) {
        this.selectedJob = { application_id: applicationId, status: 'Loading...' };
        this.showJobDetailModal = true;
        this.isJobDetailLoading = true;
        try {
            const jobData = await getJobDetail({ applicationId });
            const progress = this.parseProgress(jobData.progress);
            const formattedDetails = this.formatProgressDetails(progress);
            this.selectedJob = { ...jobData, progress: { ...progress, details: formattedDetails }, statusClass: this.getStatusClass(jobData.status), formattedProgressJson: JSON.stringify(progress, null, 2) };
        } catch (e) {
            this.showToast('Error Loading Details', this.reduceErrors(e)[0], 'error');
            this.closeJobDetailModal();
        } finally {
            this.isJobDetailLoading = false;
        }
    }

    showConfirmationModal(title, message, confirmLabel, confirmAction) {
        this.modal = { show: true, title, message, confirmLabel, confirmAction };
    }

    closeModal() {
        this.modal = { show: false };
    }

    closeJobDetailModal() {
        this.showJobDetailModal = false;
        this.selectedJob = null;
    }

    async confirmAction() {
        if (this.modal.confirmAction) await this.modal.confirmAction();
        this.closeModal();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissible' }));
    }

    reduceErrors = (errors) => [].concat(errors).filter(Boolean).map(err => err.body?.message || err.message || 'An unknown error occurred');
    parseProgress = (p) => { try { return p ? JSON.parse(p) : {}; } catch { return { error: 'Could not parse progress JSON.' }; } };
    getStatusClass = (s) => {
        const st = (s || '').toLowerCase();
        if (st.includes('completed')) return 'slds-theme_success';
        if (st.includes('failed')) return 'slds-theme_error';
        if (st.includes('processing')) return 'slds-theme_warning';
        if (st.includes('queued')) return 'slds-theme_info';
        return 'slds-theme_shade';
    }
    formatProgressSummary = (p, status) => {
        if ((status || '').toLowerCase() === 'queued') return 'Queued for processing...';
        if (!p || p.error) return 'N/A';
        const k = Object.keys(p);
        return k.length ? `${Object.values(p).filter(v => v.status?.includes('completed')).length}/${k.length} stages` : 'Starting...';
    }
    formatProgressDetails = (p) => {
        if (!p || typeof p !== 'object' || p.error) return [];
        return Object.entries(p).map(([name, details]) => {
            const status = details.status || 'unknown';
            let icon, iconClass = '';
            switch (status.toLowerCase()) {
                case 'completed': icon = 'utility:check'; iconClass = 'slds-icon-text-success'; break;
                case 'failed': icon = 'utility:error'; iconClass = 'slds-icon-text-error'; break;
                case 'processing': icon = 'utility:settings'; iconClass = 'slds-icon-text-warning'; break;
                case 'skipped': icon = 'utility:forward'; break;
                default: icon = 'utility:info';
            }
            return { name: name.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()), status: details.status, details: typeof details.details === 'string' ? details.details : JSON.stringify(details.details), icon, iconClass, statusClass: this.getStatusClass(status) };
        });
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.processLogsAnalytics();
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.processLogsAnalytics();
    }

    handleResetFilters() {
        this.startDate = null;
        this.endDate = null;
        this.processLogsAnalytics();
    }

    // ============ LOGS ANALYTICS PROCESSING ============
    processLogsAnalytics() {
        const now = new Date();
        const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

        let dailyCost = 0, weeklyCost = 0, monthlyCost = 0, totalCost = 0;
        let dailyTokens = { input: 0, output: 0 }, weeklyTokens = { input: 0, output: 0 }, monthlyTokens = { input: 0, output: 0 }, totalTokens = { input: 0, output: 0 };

        const docTypeMap = new Map(); // record_type -> { totalCost, errorCount, successCount, totalCount }
        const appExecutionMap = new Map(); // applicationId -> { applicationName, applicationUrl, executions: [], totalRetriggers, totalCost }

        for (const logEntry of this.logsData) {
            let parsedLogs = [];
            try {
                parsedLogs = JSON.parse(logEntry.logsJson || '[]');
            } catch (e) {
                continue;
            }

            if (!Array.isArray(parsedLogs)) continue;

            const relevantExecutions = [];

            for (const execution of parsedLogs) {
                const timestamp = execution.timestamp ? new Date(execution.timestamp) : null;

                // Date Range Sorting
                if (this.startDate && timestamp && timestamp < new Date(this.startDate)) continue;
                if (this.endDate && timestamp && timestamp > new Date(this.endDate)) continue;

                relevantExecutions.push(execution);

                let executionCost = 0;
                let executionTokens = { input: 0, output: 0 };

                // Process each record in the execution
                if (Array.isArray(execution.records)) {
                    for (const record of execution.records) {
                        const recordCost = parseFloat(record.total_cost) || 0;
                        executionCost += recordCost;

                        // Calculate tokens for this record
                        const currentRecordInput = (record.doc_input || 0) + (record.crew_input || 0);
                        const currentRecordOutput = (record.doc_output || 0) + (record.crew_output || 0);

                        executionTokens.input += currentRecordInput;
                        executionTokens.output += currentRecordOutput;

                        // Update document type stats
                        const recordType = record.record_type || 'Unknown';
                        if (!docTypeMap.has(recordType)) {
                            docTypeMap.set(recordType, {
                                recordType: recordType,
                                displayName: this.formatRecordTypeName(recordType),
                                totalCost: 0,
                                errorCount: 0,
                                successCount: 0,
                                skippedCount: 0,
                                totalCount: 0,
                                avgDocCost: 0,
                                avgCrewCost: 0,
                                totalDocInput: 0,
                                totalDocOutput: 0,
                                totalCrewInput: 0,
                                totalCrewOutput: 0
                            });
                        }
                        const docStats = docTypeMap.get(recordType);
                        docStats.totalCost += recordCost;
                        docStats.totalCount++;
                        docStats.totalDocInput += (record.doc_input || 0);
                        docStats.totalDocOutput += (record.doc_output || 0);
                        docStats.totalCrewInput += (record.crew_input || 0);
                        docStats.totalCrewOutput += (record.crew_output || 0);

                        const recordStatus = (record.status || '').toLowerCase();
                        if (recordStatus === 'completed') {
                            docStats.successCount++;
                        } else if (recordStatus === 'failed') {
                            docStats.errorCount++;
                        } else if (recordStatus === 'skipped') {
                            docStats.skippedCount++;
                        }
                    }
                }

                // Aggregate costs and tokens by time period
                totalCost += executionCost;
                totalTokens.input += executionTokens.input;
                totalTokens.output += executionTokens.output;

                if (timestamp) {
                    if (timestamp >= oneDayAgo) {
                        dailyCost += executionCost;
                        dailyTokens.input += executionTokens.input;
                        dailyTokens.output += executionTokens.output;
                    }
                    if (timestamp >= oneWeekAgo) {
                        weeklyCost += executionCost;
                        weeklyTokens.input += executionTokens.input;
                        weeklyTokens.output += executionTokens.output;
                    }
                    if (timestamp >= oneMonthAgo) {
                        monthlyCost += executionCost;
                        monthlyTokens.input += executionTokens.input;
                        monthlyTokens.output += executionTokens.output;
                    }
                }
            }

            if (relevantExecutions.length > 0) {
                // Initialize application execution entry only if there are relevant executions
                if (!appExecutionMap.has(logEntry.applicationId)) {
                    appExecutionMap.set(logEntry.applicationId, {
                        applicationId: logEntry.applicationId,
                        applicationName: logEntry.applicationName,
                        applicationUrl: logEntry.applicationUrl,
                        executions: [],
                        totalRetriggers: 0,
                        totalCost: 0,
                        totalTokens: { input: 0, output: 0 },
                        lastStatus: logEntry.status
                    });
                }
                const appEntry = appExecutionMap.get(logEntry.applicationId);

                // We show total retriggers as the COUNT of relevant executions in this filtered view, 
                // OR should we show the total *available* retriggers?
                // Given the filter context, showing stats for filtered items makes most sense.
                // But the user might want to know total attempts. 
                // Let's stick to showing what's in the filtered view.
                appEntry.totalRetriggers += relevantExecutions.length;

                for (const execution of relevantExecutions) {
                    const timestamp = execution.timestamp ? new Date(execution.timestamp) : null;

                    // Re-calculating execution cost/tokens for the app entry (could optimize but this is clean)
                    let executionCost = 0;
                    let executionTokens = { input: 0, output: 0 };
                    if (Array.isArray(execution.records)) {
                        for (const record of execution.records) {
                            executionCost += parseFloat(record.total_cost) || 0;
                            executionTokens.input += (record.doc_input || 0) + (record.crew_input || 0);
                            executionTokens.output += (record.doc_output || 0) + (record.crew_output || 0);
                        }
                    }

                    appEntry.executions.push({
                        count: execution.count,
                        timestamp: execution.timestamp,
                        formattedTimestamp: timestamp ? timestamp.toLocaleString() : 'N/A',
                        status: execution.status,
                        statusClass: this.getStatusClass(execution.status),
                        error: execution.error,
                        cost: executionCost.toFixed(6),
                        tokens: executionTokens,
                        records: (execution.records || []).map(r => ({
                            ...r,
                            displayName: this.formatRecordTypeName(r.record_type),
                            statusClass: this.getStatusClass(r.status),
                            formattedCost: (r.total_cost || 0).toFixed(6)
                        }))
                    });
                    appEntry.totalCost += executionCost;
                    appEntry.totalTokens.input += executionTokens.input;
                    appEntry.totalTokens.output += executionTokens.output;
                }
            }
        }

        // Finalize document type stats
        const docTypeStats = [];
        for (const [, stats] of docTypeMap) {
            stats.errorRate = stats.totalCount > 0 ? ((stats.errorCount / stats.totalCount) * 100).toFixed(1) : '0.0';
            stats.successRate = stats.totalCount > 0 ? ((stats.successCount / stats.totalCount) * 100).toFixed(1) : '0.0';
            stats.formattedCost = stats.totalCost.toFixed(6);
            stats.avgCostPerRecord = stats.totalCount > 0 ? (stats.totalCost / stats.totalCount).toFixed(6) : '0.000000';
            stats.hasErrors = stats.errorCount > 0;
            stats.successBarStyle = `width: ${Math.min(parseFloat(stats.successRate), 100)}%`;
            stats.errorBarStyle = `width: ${Math.min(parseFloat(stats.errorRate), 100)}%`;
            docTypeStats.push(stats);
        }
        // Sort by error count (descending)
        docTypeStats.sort((a, b) => b.errorCount - a.errorCount);

        // Finalize application execution history
        const appExecutionHistory = [];
        for (const [, appData] of appExecutionMap) {
            appData.formattedTotalCost = appData.totalCost.toFixed(6);
            appData.executions.sort((a, b) => b.count - a.count); // Latest execution first
            appData.latestExecution = appData.executions[0] || null;
            appData.retriggeredMultipleTimes = appData.totalRetriggers > 1;
            appExecutionHistory.push(appData);
        }
        // Sort by retrigger count (descending)
        appExecutionHistory.sort((a, b) => b.totalRetriggers - a.totalRetriggers);

        // Update tracked properties
        this.costAnalytics = {
            daily: dailyCost.toFixed(4),
            dailyTokens: dailyTokens,
            weekly: weeklyCost.toFixed(4),
            weeklyTokens: weeklyTokens,
            monthly: monthlyCost.toFixed(4),
            monthlyTokens: monthlyTokens,
            total: totalCost.toFixed(4),
            totalTokens: totalTokens
        };
        this.documentTypeStats = docTypeStats;
        this.applicationExecutionHistory = appExecutionHistory;
    }

    formatRecordTypeName(recordType) {
        if (!recordType) return 'Unknown';
        return recordType.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
    }

    viewApplicationExecutionHistory(event) {
        const applicationId = event.currentTarget.dataset.applicationId;
        const appData = this.applicationExecutionHistory.find(a => a.applicationId === applicationId);
        if (appData) {
            this.selectedApplicationLogs = appData;
            this.showExecutionHistoryModal = true;
        }
    }

    closeExecutionHistoryModal() {
        this.showExecutionHistoryModal = false;
        this.selectedApplicationLogs = null;
    }

    get hasLogsData() { return this.logsData?.length > 0; }
    get hasDocumentTypeStats() { return this.documentTypeStats?.length > 0; }
    get hasApplicationExecutionHistory() { return this.applicationExecutionHistory?.length > 0; }
    get multipleRetriesApplications() { return this.applicationExecutionHistory.filter(a => a.totalRetriggers > 1); }
    get hasMultipleRetriesApplications() { return this.multipleRetriesApplications.length > 0; }
    get topErrorDocTypes() { return this.documentTypeStats.filter(d => d.errorCount > 0).slice(0, 5); }
    get topCostlyDocTypes() {
        return [...this.documentTypeStats]
            .sort((a, b) => b.totalCost - a.totalCost)
            .slice(0, 5);
    }

    get queueData() {
        const serverData = this._wiredActiveJobsResult?.data || { active_jobs: '...', slot_utilization: { active_slots: '...', max_slots: '...', load_percent: 0 } };
        const totalCount = this._wiredTotalJobsResult?.data ?? '...';
        return { ...serverData, tracked_jobs_total: totalCount };
    }
    get hasActiveJobs() { return this.activeJobs?.length > 0; }
    get hasConcludedJobs() { return this.concludedJobs?.length > 0; }
    get hasSucceededApiLogs() { return this.succeededApiLogs?.length > 0; }
    get hasFailedApiLogs() { return this.failedApiLogs?.length > 0; }
    get retryableConcludedJobs() { return this.selectedConcludedJobs.filter(job => job.status.toLowerCase() === 'failed'); }
    get autoRefreshButtonLabel() { return `Auto-Refresh ${this.autoRefreshEnabled ? 'ON' : 'OFF'}`; }
    get autoRefreshIcon() { return `utility:${this.autoRefreshEnabled ? 'check' : 'live_message'}`; }

    // --- FIX START: Getters for disabling buttons ---
    get isMassDeleteActiveDisabled() {
        return this.selectedActiveJobs.length === 0;
    }
    get isMassDeleteConcludedDisabled() {
        return this.selectedConcludedJobs.length === 0;
    }
    get isMassRetryConcludedDisabled() {
        return this.retryableConcludedJobs.length === 0;
    }
    get isMassDeleteFailedDisabled() {
        return this.selectedFailedTransactions.length === 0;
    }
    // --- FIX END ---

    get isDateFilterActive() {
        return !!this.startDate || !!this.endDate;
    }

    get totalCardLabel() {
        return this.isDateFilterActive ? 'Selected Period' : 'Total Cost';
    }
}