import { LightningElement, api, track } from "lwc";
import getCompanyResearch from "@salesforce/apex/AccountCompanyResearchController.getCompanyResearch";
import saveCompanyResearch from "@salesforce/apex/AccountCompanyResearchController.saveCompanyResearch";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import AGENTFORCE_ICON from "@salesforce/resourceUrl/AgentforceRGBIcon";

export default class AccountResearch extends LightningElement {
  @api recordId;
  _accountId = null; // Private backing property

  agentforceIcon = AGENTFORCE_ICON;

  @track isLoading = false;
  @track isSaving = false;
  @track hasError = false;
  @track errorMessage = "";
  @track data; // LeadCompanyResearchResult
  @track currentLoadingMessage = "";
  loadingMessages = [
    "Researching company with Agentforce...",
    "Gathering web search results...",
    "Analyzing company information...",
    "Extracting key insights...",
    "Identifying growth opportunities...",
    "Compiling research summary..."
  ];
  loadingMessageInterval = null;
  loadingMessageIndex = 0;
  _analysisTrigger = null;
  previousTrigger = null;
  previousAccountId = null;

  connectedCallback() {
    // Component initialization
  }

  disconnectedCallback() {
    // Clean up interval when component is destroyed
    this.stopLoadingMessages();
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
          this.handleResearch();
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
        this.handleResearch();
      }, 0);
    }
    this._analysisTrigger = value;
  }

  get currentAccountId() {
    return this.accountId || this.recordId;
  }

  startLoadingMessages() {
    // Reset to first message
    this.loadingMessageIndex = 0;
    // Set initial message
    this.currentLoadingMessage = this.loadingMessages[this.loadingMessageIndex];
    
    // Rotate messages every 3 seconds
    this.loadingMessageInterval = setInterval(() => {
      this.loadingMessageIndex = (this.loadingMessageIndex + 1) % this.loadingMessages.length;
      this.currentLoadingMessage = this.loadingMessages[this.loadingMessageIndex];
    }, 3000);
  }

  stopLoadingMessages() {
    if (this.loadingMessageInterval) {
      clearInterval(this.loadingMessageInterval);
      this.loadingMessageInterval = null;
    }
    this.currentLoadingMessage = "";
  }

  handleResearch() {
    this.isLoading = true;
    this.hasError = false;
    this.errorMessage = "";
    this.startLoadingMessages();

    const accountIdToUse = this.currentAccountId;
    if (!accountIdToUse) {
      this.hasError = true;
      this.errorMessage = "No account ID provided.";
      this.isLoading = false;
      this.stopLoadingMessages();
      return;
    }

    getCompanyResearch({ accountId: accountIdToUse })
      .then((result) => {
        this.data = result;
        if (!result || !result.overview) {
          this.showToast("Info", "No research results returned.", "info");
        }
      })
      .catch((error) => {
        this.hasError = true;
        this.errorMessage =
          error?.body?.message ||
          error?.message ||
          "Unable to research this account.";
        this.showToast("Error", this.errorMessage, "error");
      })
      .finally(() => {
        this.isLoading = false;
        this.stopLoadingMessages();
      });
  }

  get hasData() {
    return !!this.data && !this.isLoading && !this.hasError;
  }

  get showEmptyState() {
    return !this.isLoading && !this.hasData && !this.hasError;
  }

  get hasAnyLink() {
    if (!this.data || !this.data.links) return false;
    const l = this.data.links;
    return !!(l.websiteUrl || l.linkedinUrl || l.newsSearchUrl);
  }

  get websiteHref() {
    if (!this.data || !this.data.facts || !this.data.facts.website) return null;
    const url = this.data.facts.website.trim();
    if (!url) return null;
    return url.startsWith("http") ? url : "https://" + url;
  }

  openWebsite = () => {
    if (this.data?.links?.websiteUrl) {
      window.open(this.data.links.websiteUrl, "_blank");
    }
  };

  openLinkedIn = () => {
    if (this.data?.links?.linkedinUrl) {
      window.open(this.data.links.linkedinUrl, "_blank");
    }
  };

  openNews = () => {
    if (this.data?.links?.newsSearchUrl) {
      window.open(this.data.links.newsSearchUrl, "_blank");
    }
  };

  shareToSlack = () => {
    this.showToast("Success", "Sent successfully to Slack", "success");
  };

  handleSaveToRecord() {
    this.isSaving = true;
    const htmlContent = this.formatDataAsHtml();

    const accountIdToUse = this.currentAccountId;
    if (!accountIdToUse) {
      this.showToast("Error", "No account ID provided.", "error");
      this.isSaving = false;
      return;
    }

    saveCompanyResearch({ accountId: accountIdToUse, htmlContent })
      .then((result) => {
        this.showToast("Success", result, "success");
      })
      .catch((error) => {
        const errorMsg =
          error?.body?.message ||
          error?.message ||
          "Unable to save account research.";
        this.showToast("Error", errorMsg, "error");
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  formatDataAsHtml() {
    if (!this.data) return "";

    let html = "";

    // Company Overview
    if (this.data.overview) {
      html += "<h3>Company Overview</h3>";
      html += `<p>${this.escapeHtml(this.data.overview)}</p>`;
    }

    // Company Snapshot
    if (this.data.facts) {
      html += "<br/><h3>Company Snapshot</h3>";
      html += "<ul>";

      const facts = this.data.facts;
      if (facts.industry) {
        html += `<li><strong>Industry:</strong> ${this.escapeHtml(facts.industry)}</li>`;
      }
      if (facts.headquarters) {
        html += `<li><strong>Headquarters:</strong> ${this.escapeHtml(facts.headquarters)}</li>`;
      }
      if (facts.foundedYear) {
        html += `<li><strong>Founded:</strong> ${facts.foundedYear}</li>`;
      }
      if (facts.employeeCountRange) {
        html += `<li><strong>Employees:</strong> ${this.escapeHtml(facts.employeeCountRange)}</li>`;
      }
      if (facts.keyProducts) {
        html += `<li><strong>Key Products:</strong> ${this.escapeHtml(facts.keyProducts)}</li>`;
      }
      if (facts.targetMarket) {
        html += `<li><strong>Target Market:</strong> ${this.escapeHtml(facts.targetMarket)}</li>`;
      }
      if (facts.keyExecutives) {
        html += `<li><strong>Key Executives:</strong> ${this.escapeHtml(facts.keyExecutives)}</li>`;
      }
      if (facts.website) {
        const websiteUrl = facts.website.startsWith("http")
          ? facts.website
          : "https://" + facts.website;
        html += `<li><strong>Website:</strong> <a href="${this.escapeHtml(websiteUrl)}" target="_blank" rel="noopener">${this.escapeHtml(facts.website)}</a></li>`;
      }

      html += "</ul>";
    }

    // Recent News
    if (this.data.facts && this.data.facts.recentNews) {
      html += "<br/><h3>Recent News</h3>";
      if (this.data.facts.recentNewsUrl) {
        html += `<p><a href="${this.escapeHtml(this.data.facts.recentNewsUrl)}" target="_blank" rel="noopener">${this.escapeHtml(this.data.facts.recentNews)}</a></p>`;
      } else {
        html += `<p>${this.escapeHtml(this.data.facts.recentNews)}</p>`;
      }
    }

    // Growth Indicators
    if (this.data.facts && this.data.facts.growthIndicators) {
      html += "<br/><h3>Growth Indicators</h3>";
      html += `<p>${this.escapeHtml(this.data.facts.growthIndicators)}</p>`;
    }

    // Quick Links
    if (
      this.data.links &&
      (this.data.links.websiteUrl ||
        this.data.links.linkedinUrl ||
        this.data.links.newsSearchUrl)
    ) {
      html += "<br/><h3>Quick Links</h3>";
      html += "<ul>";

      if (this.data.links.websiteUrl) {
        html += `<li><a href="${this.escapeHtml(this.data.links.websiteUrl)}" target="_blank" rel="noopener">Company Website</a></li>`;
      }
      if (this.data.links.linkedinUrl) {
        html += `<li><a href="${this.escapeHtml(this.data.links.linkedinUrl)}" target="_blank" rel="noopener">LinkedIn Profile</a></li>`;
      }
      if (this.data.links.newsSearchUrl) {
        html += `<li><a href="${this.escapeHtml(this.data.links.newsSearchUrl)}" target="_blank" rel="noopener">Recent News</a></li>`;
      }

      html += "</ul>";
    }

    // Recent Headlines
    if (this.data.headlines && this.data.headlines.length > 0) {
      html += "<br/><h3>Recent Headlines</h3>";
      html += "<ul>";

      this.data.headlines.forEach((headline) => {
        if (headline && headline.title) {
          if (headline.url) {
            html += `<li><a href="${this.escapeHtml(headline.url)}" target="_blank" rel="noopener">${this.escapeHtml(headline.title)}</a></li>`;
          } else {
            html += `<li>${this.escapeHtml(headline.title)}</li>`;
          }
        }
      });

      html += "</ul>";
    }

    return html;
  }

  escapeHtml(text) {
    if (!text) return "";
    // Create a text node to safely escape HTML special characters
    const textNode = document.createTextNode(text);
    const div = document.createElement("div");
    div.appendChild(textNode);
    return div.textContent;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
