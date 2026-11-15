import { LightningElement, track, wire } from 'lwc';
import getDashboardMetrics from '@salesforce/apex/WasteAnalyticsService.getDashboardMetrics';

export default class AdminOverview extends LightningElement {
    @track metrics = {
        totalComplaints: 0,
        newComplaints: 0,
        pendingComplaints: 0,
        inProgressComplaints: 0,
        resolvedComplaints: 0,
        criticalComplaints: 0,
        overdueComplaints: 0,
        recyclingRequests: 0,
        activeTeams: 0,
        avgResolutionHours: 0,
        totalRecycledKg: 0,
        resolutionRatePercent: 0
    };

    @wire(getDashboardMetrics)
    wiredMetrics({ data, error }) {
        if (data) {
            this.metrics = data;
        }
    }

    navigateToComplaints() { this.dispatchNav('complaints'); }
    navigateToReport() { this.dispatchNav('new_report'); }
    navigateToDispatch() { this.dispatchNav('dispatch'); }
    navigateToRecycling() { this.dispatchNav('recycling'); }
    navigateToHotspots() { this.dispatchNav('hotspots'); }
    navigateToAnalytics() { this.dispatchNav('analytics'); }

    dispatchNav(targetTab) {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { tab: targetTab }
        }));
    }
}
