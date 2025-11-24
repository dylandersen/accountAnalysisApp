import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class AccountAnalysisApp extends LightningElement {
  @track selectedAccountId = null;
  @track selectedAccountName = null;
  @track isAnalyzing = false;

  connectedCallback() {
    // Hide the default Salesforce app page header
    this.hideDefaultHeader();
  }

  hideDefaultHeader() {
    // Use setTimeout to ensure DOM is ready and flexipage has rendered
    setTimeout(() => {
      // Find the flexipage container
      const flexipageContainer = document.querySelector('.flexipageTemplate');
      if (!flexipageContainer) return;

      // Look for the default page header within the flexipage
      // The default header is typically a sibling or parent of our component
      const defaultHeaders = flexipageContainer.querySelectorAll(
        '.slds-page-header, header.slds-page-header, .slds-template__app .slds-page-header'
      );

      defaultHeaders.forEach(header => {
        // Make sure it's not our custom header
        const isOurHeader = header.closest('c-account-analysis-app') || 
                           header.querySelector('c-account-analysis-app') ||
                           header.classList.contains('header-section');
        
        if (!isOurHeader) {
          // Check if it contains "Account Analysis" text (the default title)
          const headerText = header.textContent || '';
          if (headerText.includes('Account Analysis') || 
              header.querySelector('.slds-page-header__title')) {
            header.style.display = 'none';
            header.style.visibility = 'hidden';
            header.style.height = '0';
            header.style.overflow = 'hidden';
          }
        }
      });

      // Also try to find and hide any page title elements outside our component
      const pageTitles = document.querySelectorAll(
        '.slds-page-header__title, .slds-text-heading_large, h1.slds-page-header__title'
      );
      
      pageTitles.forEach(title => {
        if (!title.closest('c-account-analysis-app')) {
          const parentHeader = title.closest('.slds-page-header, header');
          if (parentHeader && !parentHeader.classList.contains('header-section')) {
            parentHeader.style.display = 'none';
          }
        }
      });
    }, 200);
  }

  handleAccountChange(event) {
    try {
      // lightning-record-picker provides recordId in event.detail.recordId
      const accountId = event.detail.recordId;
      
      if (accountId) {
        this.selectedAccountId = accountId;
        
        // Get account name from the record if available
        if (event.detail.record && event.detail.record.fields) {
          this.selectedAccountName = event.detail.record.fields.Name?.value || null;
        } else if (event.detail.record && event.detail.record.Name) {
          this.selectedAccountName = event.detail.record.Name;
        } else {
          this.selectedAccountName = null;
        }
        
        // Auto-trigger analysis when account is selected
        this.triggerAnalysis();
      } else {
        // Clear selection if no account selected
        this.selectedAccountId = null;
        this.selectedAccountName = null;
      }
    } catch (error) {
      console.error('Error handling account change:', error);
      this.showToast('Error', 'Failed to select account. Please try again.', 'error');
    }
  }

  triggerAnalysis() {
    if (!this.selectedAccountId) {
      return;
    }

    this.isAnalyzing = true;
    
    // Increment trigger to signal child components to analyze
    this.analysisTrigger = Date.now();
    
    // Reset analyzing state after a short delay
    setTimeout(() => {
      this.isAnalyzing = false;
    }, 500);
  }

  @track analysisTrigger = 0; // Used to trigger child component analysis

  handleAnalyze() {
    if (!this.selectedAccountId) {
      this.showToast("Error", "Please select an account first", "error");
      return;
    }

    // Trigger analysis
    this.triggerAnalysis();
  }

  get hasSelectedAccount() {
    return !!this.selectedAccountId;
  }

  get isButtonDisabled() {
    return this.isAnalyzing || !this.hasSelectedAccount;
  }

  get showEmptyState() {
    return !this.selectedAccountId;
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }
}

