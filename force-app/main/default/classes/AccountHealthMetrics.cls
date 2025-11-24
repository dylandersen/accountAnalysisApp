public class AccountHealthMetrics {
  @AuraEnabled
  public Integer emailCount { get; set; }

  @AuraEnabled
  public Integer taskCount { get; set; }

  @AuraEnabled
  public Integer eventCount { get; set; }

  @AuraEnabled
  public Integer callCount { get; set; }

  @AuraEnabled
  public Integer caseCount { get; set; }

  @AuraEnabled
  public Integer openCases { get; set; }

  @AuraEnabled
  public Integer escalatedCases { get; set; }

  @AuraEnabled
  public Integer closedCases { get; set; }

  @AuraEnabled
  public Integer highPriorityOpenCases { get; set; }

  @AuraEnabled
  public Integer oppCount { get; set; }

  @AuraEnabled
  public Integer activeOpps { get; set; }

  @AuraEnabled
  public Integer wonOpps { get; set; }

  @AuraEnabled
  public Integer chatterCount { get; set; }

  @AuraEnabled
  public Decimal avgCallDuration { get; set; }

  @AuraEnabled
  public Decimal closedWonACV { get; set; }

  @AuraEnabled
  public Decimal closedLostACV { get; set; }

  public AccountHealthMetrics() {
    this.emailCount = 0;
    this.taskCount = 0;
    this.eventCount = 0;
    this.callCount = 0;
    this.caseCount = 0;
    this.openCases = 0;
    this.escalatedCases = 0;
    this.closedCases = 0;
    this.highPriorityOpenCases = 0;
    this.oppCount = 0;
    this.activeOpps = 0;
    this.wonOpps = 0;
    this.chatterCount = 0;
    this.avgCallDuration = 0;
    this.closedWonACV = 0;
    this.closedLostACV = 0;
  }
}
