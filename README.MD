# Account Analysis App

Agentforce-powered Lightning App Page that provides comprehensive account intelligence, relationship health analysis, and company research for Salesforce Accounts.

## Features

- 🤖 **Agentforce-Powered Health Scoring** - Automated 0-100 health score with status levels (Excellent, Good, Moderate, At Risk, Critical)
- 📊 **Relationship Health Analysis** - Sentiment analysis of customer communications with actionable insights
- 🔍 **Company Research** - Web-based company intelligence via Tavily API (overview, industry, products, executives, news)
- 📈 **Comprehensive Metrics** - Tracks emails, tasks, cases, opportunities, and engagement patterns
- ⚡ **Auto-Trigger Analysis** - Analysis starts automatically when an account is selected

## Prerequisites

- Salesforce Org (Developer Edition, Sandbox, or Production)
- Salesforce CLI installed and authenticated
- System Administrator permissions
- [Tavily API Key](https://tavily.com) (for company research)
- Einstein AI enabled in your org (OpenAI GPT-4o mini and Gemini 2.5 Pro)

## Quick Start

### 1. Download Assets

Download the pre-built assets: **[accountAnalysisAppAssets.zip](/accountAnalysisAppAssets.zip)**

Extract the zip file to your local machine.

### 2. Set Up Project

```bash
# Create new Salesforce project
sf project generate --name account-analysis-app
cd account-analysis-app

# Or use existing project
```

### 3. Organize Files

Copy extracted files to your project following this structure:

```
force-app/main/default/
├── lwc/
│   ├── accountAnalysisApp/
│   ├── accountRelationshipHealth/
│   └── accountResearch/
├── classes/
│   ├── AccountRelationshipHealthController.cls
│   ├── AccountCompanyResearchController.cls
│   ├── AccountHealthAnalysis.cls
│   ├── AccountHealthMetrics.cls
│   ├── LeadCompanyResearchResult.cls
│   └── AccountRelationshipHealthControllerTest.cls
└── flexipages/
    └── Account_Analysis_App.flexipage-meta.xml
```

### 4. Deploy to Org

Create `manifest/package.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>AccountRelationshipHealthController</members>
        <members>AccountRelationshipHealthControllerTest</members>
        <members>AccountCompanyResearchController</members>
        <members>AccountHealthAnalysis</members>
        <members>AccountHealthMetrics</members>
        <members>LeadCompanyResearchResult</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>accountAnalysisApp</members>
        <members>accountRelationshipHealth</members>
        <members>accountResearch</members>
        <name>LightningComponentBundle</name>
    </types>
    <types>
        <members>Account_Analysis_App</members>
        <name>FlexiPage</name>
    </types>
    <version>62.0</version>
</Package>
```

Deploy:

```bash
sf project deploy start --manifest manifest/package.xml --target-org your-org-alias
```

Run tests:

```bash
sf apex run test --class-names AccountRelationshipHealthControllerTest --result-format human
```

## Configuration

### 1. Remote Site Settings

Setup → Remote Site Settings → New Remote Site
- **Remote Site Name**: `Tavily_API`
- **Remote Site URL**: `https://api.tavily.com`
- **Active**: ✓

### 2. Tavily API Configuration

1. Create Custom Metadata Type:
   - Setup → Custom Metadata Types → New
   - **Label**: `Tavily API Config`
   - **Plural Label**: `Tavily API Configs`
   - **Object Name**: `Tavily_API_Config`

2. Add Field:
   - **Field Label**: `API Key`
   - **Field Name**: `API_Key__c`
   - **Data Type**: `Text` (Length: 255)

3. Create Record:
   - Setup → Custom Metadata Types → Tavily API Config → Manage Records → New
   - **Developer Name**: `Default` (must be exactly "Default")
   - **API Key**: Enter your Tavily API key

### 3. Enable Einstein AI

Setup → Einstein Setup → Enable **Einstein Generative AI**

Ensure your user profile has Einstein AI permissions enabled.

### 4. Create Lightning Tab

Setup → Tabs → Lightning Component Tabs → New
- **Lightning Component**: `c:accountAnalysisApp`
- **Tab Label**: `Account Analysis`
- **Icon**: Choose appropriate icon

### 5. Create App Page

Setup → App Manager → Lightning App Pages → New
- **Label**: `Account Analysis App`
- **Developer Name**: `Account_Analysis_App`
- Add `c:accountAnalysisApp` component to the page
- Activate the page

### 6. Add to App Navigation

Setup → App Manager → Edit your app → Add "Account Analysis" to navigation items

## Usage

1. Navigate to the Account Analysis tab or App Page
2. Select an Account from the picker
3. Analysis starts automatically:
   - **Relationship Health** component displays health score, metrics, insights, and recommendations
   - **Account Research** component displays company intelligence from web research

## Tech Stack

- **Lightning Web Components (LWC)** - Modern Salesforce UI framework
- **Apex** - Backend logic and data aggregation
- **Einstein AI** - OpenAI GPT-4o mini (health analysis) and Vertex AI Gemini (research parsing)
- **Tavily Search API** - Web search for company research
- **Lightning Design System (SLDS)** - Salesforce styling

## File Structure

```
force-app/main/default/
├── lwc/
│   ├── accountAnalysisApp/          # Main container component
│   ├── accountRelationshipHealth/   # Health analysis component
│   └── accountResearch/              # Company research component
├── classes/
│   ├── AccountRelationshipHealthController.cls    # Health metrics & AI
│   ├── AccountCompanyResearchController.cls        # Research & parsing
│   ├── AccountHealthAnalysis.cls                   # Analysis wrapper
│   ├── AccountHealthMetrics.cls                    # Metrics wrapper
│   ├── LeadCompanyResearchResult.cls               # Research result wrapper
│   └── AccountRelationshipHealthControllerTest.cls # Test class
└── flexipages/
    └── Account_Analysis_App.flexipage-meta.xml     # App page definition
```

## Troubleshooting

**Component not appearing**: Verify `isExposed` is `true` in component metadata and component is deployed.

**No research data**: Check Tavily API key is configured in Custom Metadata with Developer Name "Default".

**AI errors**: Verify Einstein AI is enabled and user has Einstein AI permissions.

**No health data**: Ensure Account records have related data (cases, opportunities, emails).

## License

This project is provided as-is for use in Salesforce orgs.

