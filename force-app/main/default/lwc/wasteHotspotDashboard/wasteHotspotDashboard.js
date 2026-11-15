import { LightningElement, track, wire } from 'lwc';
import getWasteHotspots from '@salesforce/apex/WasteAnalyticsService.getWasteHotspots';

export default class WasteHotspotDashboard extends LightningElement {
    @track hotspots = [];
    @track mapMarkers = [];

    get hasHotspots() {
        return this.hotspots && this.hotspots.length > 0;
    }

    get hasMapMarkers() {
        return this.mapMarkers && this.mapMarkers.length > 0;
    }

    @wire(getWasteHotspots)
    wiredHotspots({ data, error }) {
        if (data) {
            this.hotspots = data.map(h => {
                let badgeClass = 'slds-badge ';
                if (h.Risk_Level__c === 'Extreme' || h.Risk_Level__c === 'High') {
                    badgeClass += 'gt-risk-high';
                } else if (h.Risk_Level__c === 'Medium') {
                    badgeClass += 'gt-risk-medium';
                } else {
                    badgeClass += 'gt-risk-low';
                }
                return {
                    ...h,
                    riskBadgeClass: badgeClass
                };
            });

            this.mapMarkers = data
                .filter(h => h.Latitude__c != null && h.Longitude__c != null)
                .map(h => ({
                    location: {
                        Latitude: h.Latitude__c,
                        Longitude: h.Longitude__c
                    },
                    title: h.Name,
                    description: `Area: ${h.Area__c} | Risk: ${h.Risk_Level__c} | Category: ${h.Waste_Category__c}`
                }));
        } else if (error) {
            this.hotspots = [];
            this.mapMarkers = [];
        }
    }
}
