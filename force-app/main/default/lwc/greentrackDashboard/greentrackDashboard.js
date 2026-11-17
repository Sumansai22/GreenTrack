import { LightningElement, track, wire } from 'lwc';
import getDashboardMetrics from '@salesforce/apex/WasteAnalyticsService.getDashboardMetrics';
import getUserRoleContext from '@salesforce/apex/WasteAnalyticsService.getUserRoleContext';
import isGuest from '@salesforce/user/isGuest';
import { refreshApex } from '@salesforce/apex';

export default class GreentrackDashboard extends LightningElement {
    @track currentMode = 'landing'; // 'landing', 'resident', 'admin', 'team_leader', 'worker'
    @track activeTab = 'overview';
    @track selectedComplaintId = null;
    @track residentActiveTab = 'complaints';
    @track userRoleInfo = null;

    @track metrics = {
        totalComplaints: 0,
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

    wiredMetricsResult;

    @wire(getUserRoleContext)
    wiredUserRole(result) {
        if (result.data) {
            this.userRoleInfo = result.data;
            // Auto-direct authenticated staff roles to their respective dashboards
            if (!this.isGuestUser) {
                if (this.userRoleInfo.isTeamLeader) {
                    this.currentMode = 'team_leader';
                } else if (this.userRoleInfo.isWorker) {
                    this.currentMode = 'worker';
                } else if (this.userRoleInfo.isAdmin) {
                    // Admins default to landing or admin
                    this.currentMode = 'landing';
                } else if (this.userRoleInfo.isResident) {
                    this.currentMode = 'resident';
                }
            } else {
                this.currentMode = 'landing';
            }
        }
    }

    @wire(getDashboardMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            this.metrics = result.data;
        }
    }

    // Authentication & Access Getters
    get isGuestUser() {
        return isGuest || (this.userRoleInfo && this.userRoleInfo.isGuest);
    }

    get isAuthenticated() {
        return !this.isGuestUser;
    }

    get userName() {
        return this.userRoleInfo ? this.userRoleInfo.userName : '';
    }

    get canAccessAdmin() {
        return this.isAuthenticated && this.userRoleInfo && this.userRoleInfo.isAdmin;
    }

    get canAccessTeamLeader() {
        return this.isAuthenticated && this.userRoleInfo && (this.userRoleInfo.isTeamLeader || this.userRoleInfo.isAdmin);
    }

    get canAccessWorker() {
        return this.isAuthenticated && this.userRoleInfo && (this.userRoleInfo.isWorker || this.userRoleInfo.isAdmin);
    }

    get canAccessResident() {
        return this.isAuthenticated && this.userRoleInfo && (this.userRoleInfo.isResident || this.userRoleInfo.isAdmin);
    }

    // Mode Getters
    get isLandingView() {
        return this.currentMode === 'landing';
    }

    get isResidentView() {
        return this.currentMode === 'resident' && this.canAccessResident;
    }

    get isAdminView() {
        return this.currentMode === 'admin' && this.canAccessAdmin;
    }

    get isTeamLeaderView() {
        return this.currentMode === 'team_leader' && this.canAccessTeamLeader;
    }

    get isWorkerView() {
        return this.currentMode === 'worker' && this.canAccessWorker;
    }

    // Role Switchers with Authentication & Access Guards
    setLandingMode() {
        this.currentMode = 'landing';
    }

    setResidentMode() {
        if (this.isGuestUser) {
            this.navigateToLogin();
            return;
        }
        this.currentMode = 'resident';
        this.residentActiveTab = 'complaints';
    }

    setAdminMode() {
        if (!this.canAccessAdmin) {
            this.navigateToLogin();
            return;
        }
        this.currentMode = 'admin';
        this.activeTab = 'overview';
    }

    setTeamLeaderMode() {
        if (!this.canAccessTeamLeader) {
            this.navigateToLogin();
            return;
        }
        this.currentMode = 'team_leader';
    }

    setWorkerMode() {
        if (!this.canAccessWorker) {
            this.navigateToLogin();
            return;
        }
        this.currentMode = 'worker';
    }

    // Quick Actions from Landing / Resident
    handleReportWasteCTA() {
        if (this.isGuestUser) {
            this.navigateToLogin();
            return;
        }
        this.currentMode = 'resident';
        this.residentActiveTab = 'new_report';
    }

    handleRecyclingCTA() {
        if (this.isGuestUser) {
            this.navigateToLogin();
            return;
        }
        this.currentMode = 'resident';
        this.residentActiveTab = 'recycling';
    }

    handleTrackComplaintsCTA() {
        if (this.isGuestUser) {
            this.navigateToLogin();
            return;
        }
        this.currentMode = 'resident';
        this.residentActiveTab = 'complaints';
    }

    handleLoginClick() {
        this.navigateToLogin();
    }

    handleLogoutClick() {
        window.location.href = '/secur/logout.jsp';
    }

    navigateToLogin() {
        window.location.href = './login';
    }

    handleResidentTabChange(event) {
        this.residentActiveTab = event.target.value;
    }

    handleNewComplaintClick() {
        this.activeTab = 'new_report';
    }

    handleNavigate(event) {
        if (event.detail && event.detail.tab) {
            this.activeTab = event.detail.tab;
        }
    }

    handleSelectComplaint(event) {
        this.selectedComplaintId = event.detail.complaintId;
    }

    handleComplaintSubmitted(event) {
        this.selectedComplaintId = event.detail.complaintId;
        if (this.currentMode === 'resident') {
            this.residentActiveTab = 'complaints';
        } else {
            this.activeTab = 'complaints';
        }
        if (this.wiredMetricsResult) {
            refreshApex(this.wiredMetricsResult);
        }
    }

    handleComplaintUpdated() {
        const listComps = this.template.querySelectorAll('c-complaint-list');
        if (listComps) {
            listComps.forEach(comp => {
                if (typeof comp.refreshData === 'function') {
                    comp.refreshData();
                }
            });
        }
        if (this.wiredMetricsResult) {
            refreshApex(this.wiredMetricsResult);
        }
    }
}
