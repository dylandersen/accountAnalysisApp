public with sharing class LeadCompanyResearchResult {
  @AuraEnabled
  public String overview;

  @AuraEnabled
  public Facts facts;

  @AuraEnabled
  public Links links;

  @AuraEnabled
  public List<Headline> headlines;

  @AuraEnabled
  public Decimal confidence;

  public class Facts {
    @AuraEnabled
    public String industry;
    @AuraEnabled
    public String headquarters;
    @AuraEnabled
    public Integer foundedYear;
    @AuraEnabled
    public String employeeCountRange;
    @AuraEnabled
    public String website;
    @AuraEnabled
    public String keyProducts;
    @AuraEnabled
    public String targetMarket;
    @AuraEnabled
    public String keyExecutives;
    @AuraEnabled
    public String recentNews;
    @AuraEnabled
    public String recentNewsUrl;
    @AuraEnabled
    public String growthIndicators;
  }

  public class Links {
    @AuraEnabled
    public String websiteUrl;
    @AuraEnabled
    public String linkedinUrl;
    @AuraEnabled
    public String newsSearchUrl;
  }

  public class Headline {
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String url;
  }

  public static LeadCompanyResearchResult parse(String jsonText) {
    if (String.isBlank(jsonText)) {
      return fallback();
    }
    try {
      return (LeadCompanyResearchResult) JSON.deserialize(
        jsonText,
        LeadCompanyResearchResult.class
      );
    } catch (Exception e) {
      System.debug('LeadCompanyResearchResult.parse error: ' + e.getMessage());
      return fallback();
    }
  }

  public static LeadCompanyResearchResult fallback() {
    LeadCompanyResearchResult r = new LeadCompanyResearchResult();
    r.overview = 'Company research is temporarily unavailable.';
    r.facts = new Facts();
    r.links = new Links();
    r.headlines = new List<Headline>();
    r.confidence = 0;
    return r;
  }
}
