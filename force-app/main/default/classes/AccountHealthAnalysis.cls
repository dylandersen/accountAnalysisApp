public class AccountHealthAnalysis {
    @AuraEnabled
    public String healthStatus { get; set; }
    
    @AuraEnabled
    public Integer score { get; set; }
    
    @AuraEnabled
    public String trend { get; set; }
    
    @AuraEnabled
    public List<String> keyInsights { get; set; }
    
    @AuraEnabled
    public List<String> recommendedActions { get; set; }
    
    @AuraEnabled
    public AccountHealthMetrics metrics { get; set; }
    
    @AuraEnabled
    public String errorMessage { get; set; }
    
    public AccountHealthAnalysis() {
        this.healthStatus = 'Unknown';
        this.score = 0;
        this.trend = 'Stable';
        this.keyInsights = new List<String>();
        this.recommendedActions = new List<String>();
        this.metrics = new AccountHealthMetrics();
    }
}


