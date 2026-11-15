import { LightningElement, track, wire } from 'lwc';
import getComplaintsByWasteType from '@salesforce/apex/WasteAnalyticsService.getComplaintsByWasteType';
import getComplaintsBySeverity from '@salesforce/apex/WasteAnalyticsService.getComplaintsBySeverity';
import getComplaintsByArea from '@salesforce/apex/WasteAnalyticsService.getComplaintsByArea';
import getMonthlyTrends from '@salesforce/apex/WasteAnalyticsService.getMonthlyTrends';
import getSLAComplianceMetrics from '@salesforce/apex/WasteAnalyticsService.getSLAComplianceMetrics';

export default class SustainabilityAnalytics extends LightningElement {
    @track wasteTypes = [];
    @track severities = [];
    @track areas = [];
    @track monthlyTrends = [];

    @track slaComplianceRate = 100;
    @track compliantComplaints = 0;
    @track breachedComplaints = 0;

    get hasWasteTypes() { return this.wasteTypes && this.wasteTypes.length > 0; }
    get hasSeverities() { return this.severities && this.severities.length > 0; }
    get hasAreas() { return this.areas && this.areas.length > 0; }

    get slaProgressStyle() {
        return `width: ${this.slaComplianceRate}%;`;
    }

    @wire(getSLAComplianceMetrics)
    wiredSLA({ data, error }) {
        if (data) {
            this.slaComplianceRate = data.complianceRatePercent != null ? data.complianceRatePercent : 100;
            this.compliantComplaints = data.compliantCount || 0;
            this.breachedComplaints = data.breachedCount || 0;
        }
    }

    @wire(getComplaintsByWasteType)
    wiredWasteTypes({ data, error }) {
        if (data) {
            this.wasteTypes = data.map(item => ({
                ...item,
                barStyle: `width: ${item.percentage || 10}%;`
            }));
        }
    }

    @wire(getComplaintsBySeverity)
    wiredSeverities({ data, error }) {
        if (data) {
            const total = data.reduce((acc, curr) => acc + curr.value, 0);
            this.severities = data.map(item => {
                const pct = total > 0 ? ((item.value / total) * 100).toFixed(1) : 0;
                let barColor = '#2e7d32';
                if (item.label === 'Critical') barColor = '#c62828';
                else if (item.label === 'High') barColor = '#ef6c00';
                else if (item.label === 'Medium') barColor = '#1565c0';

                return {
                    ...item,
                    percentage: pct,
                    barStyle: `width: ${pct}%; background-color: ${barColor};`
                };
            });
        }
    }

    @wire(getComplaintsByArea)
    wiredAreas({ data, error }) {
        if (data) {
            const total = data.reduce((acc, curr) => acc + curr.value, 0);
            this.areas = data.map(item => {
                const pct = total > 0 ? ((item.value / total) * 100).toFixed(1) : 0;
                return {
                    ...item,
                    percentage: pct,
                    barStyle: `width: ${pct}%;`
                };
            });
        }
    }

    @wire(getMonthlyTrends)
    wiredTrends({ data, error }) {
        if (data) {
            this.monthlyTrends = data;
        }
    }
}
