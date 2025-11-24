import { LightningElement, api, track } from "lwc";
import getRelationshipHealth from "@salesforce/apex/AccountRelationshipHealthController.getRelationshipHealth";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import AGENTFORCE_ICON from "@salesforce/resourceUrl/AgentforceIcon";

export default class AccountRelationshipHealth extends LightningElement {
  @api recordId;
  _accountId = null; // Private backing property
  @track healthData;
  @track metrics;
  @track isLoading = false;
  @track hasError = false;
  @track errorMessage = "";
  agentforceIcon = AGENTFORCE_ICON;
  _analysisTrigger = null;
  previousTrigger = null;
  previousAccountId = null;

  connectedCallback() {
    // Optionally load on initial page load
    // this.handleRefresh();
  }

  @api
  get accountId() {
    return this._accountId;
  }

  set accountId(value) {
    // Track previous value to detect changes
    const oldValue = this._accountId;
    this._accountId = value;
    
    // If accountId changed and we have a valid ID, trigger analysis
    if (value && value !== oldValue && value !== this.previousAccountId) {
      this.previousAccountId = value;
      // Use setTimeout to ensure property is fully set
      setTimeout(() => {
        if (this.currentAccountId === value) {
          this.handleRefresh();
        }
      }, 100);
    }
  }

  @api
  get analysisTrigger() {
    return this._analysisTrigger;
  }

  set analysisTrigger(value) {
    if (value && value !== this.previousTrigger && this.currentAccountId) {
      this.previousTrigger = value;
      // Use setTimeout to ensure this runs after the property is set
      setTimeout(() => {
        this.handleRefresh();
      }, 0);
    }
    this._analysisTrigger = value;
  }

  get currentAccountId() {
    return this.accountId || this.recordId;
  }

  handleRefresh() {
    this.isLoading = true;
    this.hasError = false;
    this.errorMessage = "";

    const accountIdToUse = this.currentAccountId;
    if (!accountIdToUse) {
      this.hasError = true;
      this.errorMessage = "No account ID provided.";
      this.isLoading = false;
      return;
    }

    getRelationshipHealth({ accountId: accountIdToUse })
      .then((result) => {
        this.healthData = {
          healthStatus: result.healthStatus,
          score: result.score,
          trend: result.trend,
          keyInsights: result.keyInsights || [],
          recommendedActions: result.recommendedActions || []
        };
        this.metrics = result.metrics;

        if (result.errorMessage) {
          this.hasError = true;
          this.errorMessage = result.errorMessage;
          this.showToast("Warning", result.errorMessage, "warning");
        }
      })
      .catch((error) => {
        this.hasError = true;
        this.errorMessage = "Unable to load relationship health data.";
        console.error("Error loading health data:", error);
        this.showToast(
          "Error",
          "Failed to load relationship health: " +
            (error.body?.message || error.message),
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }

  get hasData() {
    return this.healthData && !this.isLoading;
  }

  get healthEmoji() {
    if (!this.healthData) return "❓";
    switch (this.healthData.healthStatus) {
      case "Excellent":
        return "🌟";
      case "Good":
        return "✅";
      case "Moderate":
        return "⚠️";
      case "At Risk":
        return "🔴";
      case "Critical":
        return "🚨";
      default:
        return "❓";
    }
  }

  get healthStatusClass() {
    if (!this.healthData) return "unknown";
    const status = this.healthData.healthStatus
      ?.toLowerCase()
      .replace(" ", "-");
    return status || "unknown";
  }

  get trendIcon() {
    if (!this.healthData) return "utility:forward";
    switch (this.healthData.trend) {
      case "Improving":
        return "utility:arrowup";
      case "Declining":
        return "utility:arrowdown";
      case "Stable":
        return "utility:forward";
      default:
        return "utility:forward";
    }
  }

  get trendClass() {
    if (!this.healthData) return "";
    switch (this.healthData.trend) {
      case "Improving":
        return "trend-improving";
      case "Declining":
        return "trend-declining";
      case "Stable":
        return "trend-stable";
      default:
        return "";
    }
  }

  get showEmptyState() {
    return !this.isLoading && !this.hasData && !this.hasError;
  }

  // Circular progress gauge calculations
  get scoreColor() {
    if (!this.healthData) return "#dddbda";
    const score = this.healthData.score;
    if (score >= 80) return "#4bca81"; // Green - Excellent/Good
    if (score >= 60) return "#ffb75d"; // Yellow - Moderate
    if (score >= 40) return "#fe9339"; // Orange - At Risk
    return "#ea001e"; // Red - Critical
  }

  get progressDashArray() {
    const circumference = 2 * Math.PI * 70; // radius = 70
    return circumference;
  }

  get progressDashOffset() {
    if (!this.healthData) return this.progressDashArray;
    const circumference = this.progressDashArray;
    const score = this.healthData.score;
    const progress = score / 100;
    return circumference * (1 - progress);
  }

  // Format ACV values to K or M notation
  get closedWonACVFormatted() {
    if (!this.metrics || !this.metrics.closedWonACV) return "$0";
    return this.formatCurrency(this.metrics.closedWonACV);
  }

  get closedLostACVFormatted() {
    if (!this.metrics || !this.metrics.closedLostACV) return "$0";
    return this.formatCurrency(this.metrics.closedLostACV);
  }

  formatCurrency(value) {
    if (value >= 1000000) {
      return "$" + (value / 1000000).toFixed(1) + "M";
    } else if (value >= 1000) {
      return "$" + (value / 1000).toFixed(1) + "K";
    }
    return "$" + value.toFixed(0);
  }

  // Case tooltip details
  get caseOpenCount() {
    return this.metrics?.openCases || 0;
  }

  get caseClosedCount() {
    return this.metrics?.closedCases || 0;
  }

  get caseTotalCount() {
    return this.metrics?.caseCount || 0;
  }

  get caseHighPriorityOpen() {
    return this.metrics?.highPriorityOpenCases || 0;
  }

  get showHighPriorityWarning() {
    return this.caseHighPriorityOpen > 0;
  }
}
