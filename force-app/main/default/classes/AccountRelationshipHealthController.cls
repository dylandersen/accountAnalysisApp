public with sharing class AccountRelationshipHealthController {
  @AuraEnabled(cacheable=false)
  public static AccountHealthAnalysis getRelationshipHealth(Id accountId) {
    AccountHealthAnalysis analysis = new AccountHealthAnalysis();

    try {
      // Gather all metrics
      AccountHealthMetrics metrics = gatherMetrics(accountId);
      analysis.metrics = metrics;

      // Build detailed context for AI analysis
      String contextData = buildContextData(accountId, metrics);

      // ADVANCED SENTIMENT ANALYSIS: Two-pass approach
      // Pass 1: Analyze emails for detailed sentiment scoring
      String emailSentimentAnalysis = analyzeEmailSentiment(accountId);

      // Pass 2: Call Einstein GenAI for comprehensive analysis with sentiment data
      String aiResponse = callEinsteinAI(contextData, emailSentimentAnalysis);

      // Parse AI response
      parseAIResponse(aiResponse, analysis);
    } catch (Exception e) {
      System.debug('Error in getRelationshipHealth: ' + e.getMessage());
      analysis.errorMessage =
        'Unable to analyze relationship health: ' + e.getMessage();
      analysis.healthStatus = 'Unknown';
      analysis.score = 0;
      analysis.keyInsights = new List<String>{
        'Error analyzing data. Please try again.'
      };
      analysis.recommendedActions = new List<String>{
        'Refresh to retry analysis.'
      };
    }

    return analysis;
  }

  private static AccountHealthMetrics gatherMetrics(Id accountId) {
    AccountHealthMetrics metrics = new AccountHealthMetrics();

    // Query EmailMessages
    List<EmailMessage> emails = [
      SELECT Id, MessageDate, Subject, TextBody, Status
      FROM EmailMessage
      WHERE RelatedToId = :accountId AND MessageDate = LAST_N_DAYS:90
      LIMIT 1000
    ];
    metrics.emailCount = emails.size();

    // Query Tasks (includes calls)
    List<Task> tasks = [
      SELECT Id, CreatedDate, Status, Subject, CallType, CallDurationInSeconds
      FROM Task
      WHERE
        (WhatId = :accountId
        OR AccountId = :accountId)
        AND CreatedDate = LAST_N_DAYS:90
      LIMIT 1000
    ];
    metrics.taskCount = tasks.size();

    // Count calls and calculate average duration
    Decimal totalCallDuration = 0;
    Integer callCount = 0;
    for (Task t : tasks) {
      if (t.CallType != null || t.Subject?.containsIgnoreCase('call')) {
        callCount++;
        if (t.CallDurationInSeconds != null) {
          totalCallDuration += t.CallDurationInSeconds;
        }
      }
    }
    metrics.callCount = callCount;
    metrics.avgCallDuration = callCount > 0
      ? (totalCallDuration / callCount / 60)
      : 0;

    // Query Events (meetings)
    List<Event> events = [
      SELECT Id, StartDateTime, Subject, EventSubtype, DurationInMinutes
      FROM Event
      WHERE WhatId = :accountId AND StartDateTime = LAST_N_DAYS:90
      LIMIT 1000
    ];
    metrics.eventCount = events.size();

    // Query Cases
    List<Case> cases = [
      SELECT Id, CreatedDate, Status, Priority, ClosedDate, IsClosed
      FROM Case
      WHERE AccountId = :accountId AND CreatedDate = LAST_N_DAYS:90
      LIMIT 1000
    ];
    metrics.caseCount = cases.size();

    Integer openCases = 0;
    Integer closedCases = 0;
    Integer escalatedCases = 0;
    Integer highPriorityOpenCases = 0;
    for (Case c : cases) {
      if (!c.IsClosed) {
        openCases++;
        // Track high priority cases that are still open
        if (c.Priority == 'High' || c.Priority == 'Urgent') {
          highPriorityOpenCases++;
        }
      } else {
        closedCases++;
      }
      if (c.Priority == 'High' || c.Priority == 'Urgent') {
        escalatedCases++;
      }
    }
    metrics.openCases = openCases;
    metrics.closedCases = closedCases;
    metrics.escalatedCases = escalatedCases;
    metrics.highPriorityOpenCases = highPriorityOpenCases;

    // Query Opportunities
    List<Opportunity> opps = [
      SELECT Id, LastModifiedDate, StageName, Amount, IsClosed, IsWon, CloseDate
      FROM Opportunity
      WHERE AccountId = :accountId AND LastModifiedDate = LAST_N_DAYS:90
      LIMIT 1000
    ];
    metrics.oppCount = opps.size();

    Integer activeOpps = 0;
    Integer wonOpps = 0;
    Decimal closedWonACV = 0;
    Decimal closedLostACV = 0;

    for (Opportunity opp : opps) {
      if (!opp.IsClosed) {
        activeOpps++;
      } else if (opp.IsWon) {
        wonOpps++;
        // Calculate closed-won ACV for opportunities closed in last 90 days
        if (
          opp.CloseDate != null &&
          opp.CloseDate >= Date.today().addDays(-90) &&
          opp.Amount != null
        ) {
          closedWonACV += opp.Amount;
        }
      } else if (opp.IsClosed && !opp.IsWon) {
        // Calculate closed-lost ACV for opportunities closed in last 90 days
        if (
          opp.CloseDate != null &&
          opp.CloseDate >= Date.today().addDays(-90) &&
          opp.Amount != null
        ) {
          closedLostACV += opp.Amount;
        }
      }
    }
    metrics.activeOpps = activeOpps;
    metrics.wonOpps = wonOpps;
    metrics.closedWonACV = closedWonACV;
    metrics.closedLostACV = closedLostACV;

    // Query Chatter posts
    List<FeedItem> chatterPosts = [
      SELECT Id, CreatedDate, Body, Type
      FROM FeedItem
      WHERE ParentId = :accountId AND CreatedDate = LAST_N_DAYS:90
      LIMIT 1000
    ];
    metrics.chatterCount = chatterPosts.size();

    return metrics;
  }

  private static String analyzeEmailSentiment(Id accountId) {
    // Query recent emails for detailed sentiment analysis
    List<EmailMessage> emails = [
      SELECT Subject, TextBody, MessageDate, FromAddress, ToAddress
      FROM EmailMessage
      WHERE RelatedToId = :accountId AND MessageDate = LAST_N_DAYS:90
      ORDER BY MessageDate DESC
      LIMIT 15
    ];

    if (emails.isEmpty()) {
      return 'No email communication available for sentiment analysis.';
    }

    // Build email content for AI sentiment analysis
    String emailContent = '';
    Integer emailNum = 1;
    for (EmailMessage em : emails) {
      if (String.isBlank(em.Subject) && String.isBlank(em.TextBody)) {
        continue;
      }

      emailContent +=
        'Email ' +
        emailNum +
        ' (Date: ' +
        em.MessageDate +
        '):\n';
      emailContent +=
        'Subject: ' +
        (String.isNotBlank(em.Subject) ? em.Subject : 'No subject') +
        '\n';

      if (String.isNotBlank(em.TextBody)) {
        String bodyText = em.TextBody.length() > 800
          ? em.TextBody.substring(0, 800) + '...'
          : em.TextBody;
        emailContent += 'Content: ' + bodyText + '\n\n';
      }
      emailNum++;
    }

    // Call AI for sophisticated sentiment analysis
    String sentimentPrompt =
      'You are an expert in communication psychology and sentiment analysis. Analyze these customer emails with DEEP CONTEXTUAL UNDERSTANDING.\n\n' +
      emailContent +
      '\n\n' +
      'Perform ADVANCED sentiment analysis and return ONLY valid JSON:\n' +
      '{\n' +
      '  "overallSentiment": "Highly Positive|Positive|Neutral|Negative|Highly Negative",\n' +
      '  "sentimentScore": 0.7,\n' +
      '  "sentimentTrajectory": "Improving|Stable|Declining|Volatile",\n' +
      '  "confidenceLevel": 0.85,\n' +
      '  "emailAnalysis": [\n' +
      '    {\n' +
      '      "emailNumber": 1,\n' +
      '      "sentimentScore": 0.6,\n' +
      '      "sentiment": "Positive|Neutral|Negative",\n' +
      '      "urgency": "Low|Medium|High|Critical",\n' +
      '      "tone": "Professional|Casual|Frustrated|Appreciative|Demanding|etc",\n' +
      '      "keyThemes": ["theme1", "theme2"],\n' +
      '      "emotionalIndicators": ["indicator1", "indicator2"]\n' +
      '    }\n' +
      '  ],\n' +
      '  "relationshipDynamics": {\n' +
      '    "formalityShift": "More formal|Less formal|Stable",\n' +
      '    "responsePattern": "Detailed|Brief|Declining engagement",\n' +
      '    "concernPatterns": ["pattern1", "pattern2"]\n' +
      '  },\n' +
      '  "topThemes": [\n' +
      '    {\n' +
      '      "theme": "Theme name",\n' +
      '      "sentiment": "Positive|Neutral|Negative",\n' +
      '      "frequency": 3,\n' +
      '      "context": "Brief context"\n' +
      '    }\n' +
      '  ],\n' +
      '  "criticalFindings": ["finding1", "finding2"],\n' +
      '  "representativeQuotes": ["quote1", "quote2", "quote3"]\n' +
      '}\n\n' +
      'ADVANCED ANALYSIS INSTRUCTIONS:\n' +
      '1. sentimentScore: -1.0 (very negative) to +1.0 (very positive)\n' +
      '2. Analyze CONTEXT, not just keywords - understand what the customer truly means\n' +
      '3. Detect subtle signals: sarcasm, passive aggression, diminishing enthusiasm, formality changes\n' +
      '4. Identify sentiment TRAJECTORY: Are emotions escalating or de-escalating over time?\n' +
      '5. Separate URGENCY from SENTIMENT: Urgent != Negative, Calm != Positive\n' +
      '6. Detect relationship dynamics: Power shifts, trust levels, engagement quality\n' +
      '7. Theme-based sentiment: Same customer can be happy about Product A but frustrated with Support\n' +
      '8. Identify CRITICAL FINDINGS: Red flags that require immediate attention\n' +
      '9. Note communication pattern changes: Response length, formality, time between messages\n' +
      '10. Assess confidence: How certain are you about this sentiment reading?\n' +
      '11. EXTRACT SHORT QUOTES: Include 1-3 brief, representative quotes (10-20 words each) from emails that justify your sentiment assessment\n\n' +
      'EXAMPLES OF SOPHISTICATED ANALYSIS:\n' +
      '- "Thanks for getting back to me" in email 1 vs "Thanks for FINALLY getting back to me" in email 5 = declining sentiment\n' +
      '- Shift from detailed questions to one-word responses = disengagement\n' +
      '- Increased formality when previously casual = relationship tension\n' +
      '- Multiple urgent requests without acknowledgment of previous resolutions = accumulated frustration\n' +
      '- Asking about competitors or alternatives = churn risk signal\n\n' +
      'CRITICAL: Include a "representativeQuotes" field in your JSON with 1-3 SHORT quotes from the emails that best demonstrate the sentiment you detected.\n' +
      'Return ONLY the JSON with no markdown formatting.';

    try {
      String modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

      aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
      request.modelName = modelName;

      aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
      request.body = requestBody;
      requestBody.prompt = sentimentPrompt;

      aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
      aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(
        request
      );

      if (response.Code200 != null && response.Code200.generation != null) {
        return response.Code200.generation.generatedText;
      } else {
        return 'Sentiment analysis unavailable.';
      }
    } catch (Exception e) {
      System.debug('Sentiment Analysis Error: ' + e.getMessage());
      return 'Sentiment analysis unavailable.';
    }
  }

  private static String buildContextData(
    Id accountId,
    AccountHealthMetrics metrics
  ) {
    // Get sample emails WITH BODY CONTENT for sentiment analysis
    List<Map<String, String>> emailDetails = new List<Map<String, String>>();
    List<EmailMessage> recentEmails = [
      SELECT Subject, TextBody, MessageDate
      FROM EmailMessage
      WHERE RelatedToId = :accountId AND MessageDate = LAST_N_DAYS:90
      ORDER BY MessageDate DESC
      LIMIT 15
    ];
    for (EmailMessage em : recentEmails) {
      // Only include emails that have subject or body content
      if (String.isBlank(em.Subject) && String.isBlank(em.TextBody)) {
        continue;
      }

      Map<String, String> emailData = new Map<String, String>();
      emailData.put(
        'subject',
        String.isNotBlank(em.Subject) ? em.Subject : 'No subject'
      );

      // Truncate email body to first 500 characters to avoid token limits
      if (String.isNotBlank(em.TextBody)) {
        String truncatedBody = em.TextBody.length() > 500
          ? em.TextBody.substring(0, 500) + '...'
          : em.TextBody;
        emailData.put('body', truncatedBody);
      } else {
        emailData.put('body', 'No content');
      }

      emailData.put('date', String.valueOf(em.MessageDate));
      emailDetails.add(emailData);
    }

    List<String> taskSubjects = new List<String>();
    List<Task> recentTasks = [
      SELECT Subject
      FROM Task
      WHERE
        (WhatId = :accountId
        OR AccountId = :accountId)
        AND CreatedDate = LAST_N_DAYS:90
        AND Subject != NULL
      ORDER BY CreatedDate DESC
      LIMIT 10
    ];
    for (Task t : recentTasks) {
      if (String.isNotBlank(t.Subject)) {
        taskSubjects.add(t.Subject);
      }
    }

    List<String> casePriorities = new List<String>();
    List<Case> recentCases = [
      SELECT Priority, Subject
      FROM Case
      WHERE AccountId = :accountId AND CreatedDate = LAST_N_DAYS:90
      ORDER BY CreatedDate DESC
      LIMIT 10
    ];
    for (Case c : recentCases) {
      casePriorities.add(
        c.Priority + ': ' + (c.Subject != null ? c.Subject : 'No subject')
      );
    }

    // Get closed-won and closed-lost opportunity details
    List<Opportunity> wonOpportunities = [
      SELECT Name, Amount, CloseDate
      FROM Opportunity
      WHERE
        AccountId = :accountId
        AND IsWon = TRUE
        AND CloseDate = LAST_N_DAYS:90
      ORDER BY CloseDate DESC
      LIMIT 10
    ];

    List<Opportunity> lostOpportunities = [
      SELECT Name, Amount, CloseDate
      FROM Opportunity
      WHERE
        AccountId = :accountId
        AND IsClosed = TRUE
        AND IsWon = FALSE
        AND CloseDate = LAST_N_DAYS:90
      ORDER BY CloseDate DESC
      LIMIT 10
    ];

    // Build context string
    String context = 'Account Relationship Health Analysis\n\n';
    context += 'QUANTITATIVE METRICS (Last 90 Days):\n';
    context += '- Emails: ' + metrics.emailCount + '\n';
    context += '- Tasks/Activities: ' + metrics.taskCount + '\n';
    context +=
      '- Calls: ' +
      metrics.callCount +
      ' (Avg duration: ' +
      metrics.avgCallDuration.setScale(1) +
      ' mins)\n';
    context += '- Meetings: ' + metrics.eventCount + '\n';
    context +=
      '- Cases: ' +
      metrics.caseCount +
      ' (Open: ' +
      metrics.openCases +
      ', High Priority: ' +
      metrics.escalatedCases +
      ')\n';
    context +=
      '- Opportunities: ' +
      metrics.oppCount +
      ' (Active: ' +
      metrics.activeOpps +
      ', Closed Won: ' +
      metrics.wonOpps +
      ')\n';
    context += '- Chatter Posts: ' + metrics.chatterCount + '\n\n';

    context += 'CLOSED-WON OPPORTUNITIES (Last 90 Days) - CELEBRATE THESE WINS:\n';
    if (!wonOpportunities.isEmpty()) {
      Decimal totalWonAmount = 0;
      for (Opportunity opp : wonOpportunities) {
        String oppAmount = opp.Amount != null
          ? '$' + String.valueOf(opp.Amount.setScale(0).format())
          : '$0';
        String oppDate = opp.CloseDate != null
          ? String.valueOf(opp.CloseDate)
          : 'Unknown date';
        context +=
          '  - ' +
          opp.Name +
          ': ' +
          oppAmount +
          ' (Closed: ' +
          oppDate +
          ')\n';
        if (opp.Amount != null) {
          totalWonAmount += opp.Amount;
        }
      }
      context +=
        'TOTAL CLOSED-WON: $' +
        String.valueOf(totalWonAmount.setScale(0).format()) +
        ' from ' +
        wonOpportunities.size() +
        ' deals\n\n';
    } else {
      context += '  - No closed-won opportunities in the last 90 days\n\n';
    }

    context += 'CLOSED-LOST OPPORTUNITIES (Last 90 Days):\n';
    if (!lostOpportunities.isEmpty()) {
      Decimal totalLostAmount = 0;
      for (Opportunity opp : lostOpportunities) {
        String oppAmount = opp.Amount != null
          ? '$' + String.valueOf(opp.Amount.setScale(0).format())
          : '$0';
        String oppDate = opp.CloseDate != null
          ? String.valueOf(opp.CloseDate)
          : 'Unknown date';
        context +=
          '  - ' +
          opp.Name +
          ': ' +
          oppAmount +
          ' (Closed: ' +
          oppDate +
          ')\n';
        if (opp.Amount != null) {
          totalLostAmount += opp.Amount;
        }
      }
      context +=
        'TOTAL CLOSED-LOST: $' +
        String.valueOf(totalLostAmount.setScale(0).format()) +
        ' from ' +
        lostOpportunities.size() +
        ' deals\n\n';
    } else {
      context += '  - No closed-lost opportunities in the last 90 days\n\n';
    }

    context += 'EMAIL CONTENT ANALYSIS - ANALYZE SENTIMENT, TONE, AND THEMES:\n';
    if (!emailDetails.isEmpty()) {
      context += 'Recent emails with content (most recent first):\n';
      Integer emailNum = 1;
      for (Map<String, String> email : emailDetails) {
        context += '\nEmail #' + emailNum + ' (' + email.get('date') + '):\n';
        context += 'Subject: ' + email.get('subject') + '\n';
        context += 'Content: ' + email.get('body') + '\n';
        emailNum++;
      }
      context += '\n';
      context += 'INSTRUCTIONS FOR EMAIL ANALYSIS:\n';
      context += '- Analyze the sentiment: Are customers happy, frustrated, angry, neutral, or urgent?\n';
      context += '- Identify themes: What are customers talking about? (product issues, pricing, support, new features, etc.)\n';
      context += '- Look for escalation signals: Words like "urgent", "escalate", "disappointed", "frustrated", "unacceptable"\n';
      context += '- Identify positive signals: Words like "thanks", "great", "excellent", "appreciate", "satisfied"\n';
      context += '- Note communication patterns: Are emails professional? Terse? Detailed? Emotional?\n';
      context += '- Assess engagement level: Are customers actively communicating or going silent?\n\n';
    } else {
      context += '  - No email content available for sentiment analysis\n\n';
    }

    context += 'QUALITATIVE SIGNALS:\n';
    if (!taskSubjects.isEmpty()) {
      context += 'Recent Task Subjects:\n';
      for (String subj : taskSubjects) {
        context += '  - ' + subj + '\n';
      }
    }

    if (!casePriorities.isEmpty()) {
      context += 'Recent Cases:\n';
      for (String caseInfo : casePriorities) {
        context += '  - ' + caseInfo + '\n';
      }
    }

    return context;
  }

  private static String callEinsteinAI(
    String contextData,
    String sentimentAnalysis
  ) {
    String promptText =
      'You are analyzing customer relationship health for a Salesforce account. ' +
      'Analyze both QUANTITATIVE metrics (frequency, volume, trends) and QUALITATIVE signals ' +
      '(sentiment in descriptions, urgency keywords, engagement patterns, email content tone).\n\n' +
      contextData +
      '\n\n' +
      '=== ADVANCED SENTIMENT ANALYSIS RESULTS ===\n' +
      'A sophisticated AI sentiment analysis has been performed on customer emails. Use this data as the PRIMARY source for sentiment insights:\n\n' +
      sentimentAnalysis +
      '\n\n' +
      '=== END SENTIMENT ANALYSIS ===\n\n' +
      'You MUST respond with ONLY valid JSON in this EXACT format (no markdown, no code blocks, just the JSON):\n' +
      '{\n' +
      '  "healthStatus": "Excellent|Good|Moderate|At Risk|Critical",\n' +
      '  "score": 60,\n' +
      '  "trend": "Improving|Stable|Declining",\n' +
      '  "keyInsights": ["insight1", "insight2", "insight3"],\n' +
      '  "recommendedActions": ["action1", "action2"]\n' +
      '}\n\n' +
      'Hard constraints:\n' +
      '- The "score" must be set EXACTLY by mapping the chosen "healthStatus" using this mapping only:\n' +
      '- {"Excellent":95,"Good":80,"Moderate":60,"At Risk":40,"Critical":20}\n' +
      '- Do NOT return any score value outside this mapping. The score must be an integer.\n\n' +
      'Scoring guidelines:\n' +
      '- Excellent (90-100): High activity, positive sentiment, no red flags, strong engagement\n' +
      '- Good (70-89): Consistent activity, stable engagement, minor issues\n' +
      '- Moderate (50-69): Adequate activity but declining trends or some concerns\n' +
      '- At Risk (30-49): Low activity, negative signals, cases increasing, poor engagement\n' +
      '- Critical (0-29): Minimal engagement, urgent issues, high escalation, at-risk relationship\n\n' +
      'Consider:\n' +
      '- Activity frequency and trends over time (are things increasing or decreasing?)\n' +
      '- Case volume and severity as health indicators\n' +
      '- Email/task sentiment and urgency keywords (urgent, issue, problem, escalate, etc.)\n' +
      '- EMAIL CONTENT SENTIMENT: Analyze the actual email content provided - are customers happy, frustrated, angry, or neutral?\n' +
      '- EMAIL THEMES: What topics are customers discussing? Product issues? Pricing concerns? Feature requests?\n' +
      '- TONE SHIFTS: Has communication become more negative or terse over time?\n' +
      '- Opportunity momentum and win rates\n' +
      '- Balance of proactive engagement vs reactive support\n\n' +
      'CRITICAL INSTRUCTIONS FOR KEY INSIGHTS:\n' +
      '- Provide 3-5 insights that are SPECIFIC and ANALYTICAL with exact data points\n' +
      '- MANDATORY: Include actual customer email quotes (from the sentiment analysis) in your insights to show WHY the sentiment is what it is\n' +
      '- Use first-person plural (we, us, our) when referring to the company\n' +
      '- Use "customer" instead of "client"\n' +
      '- For each metric mentioned, explain WHAT IT MEANS and WHY IT MATTERS\n' +
      '- IMPORTANT: Return plain text with <strong> HTML tags for bold formatting (NOT markdown **)\n' +
      '- Use <strong></strong> HTML tags for important metrics, dollar amounts, numbers, key callouts, and EMAIL QUOTES\n\n' +
      'INSIGHT PRIORITY RULES:\n' +
      '1. **ALWAYS prioritize closed-won deals first** - If there are ANY closed-won opportunities in the last 90 days, dedicate the FIRST insight to celebrating those wins with specific dollar amounts and deal counts\n' +
      '2. **MANDATORY: INCLUDE EMAIL QUOTES IN INSIGHTS** - If the sentiment analysis contains email data:\n' +
      '   - You MUST include at least 1-2 actual email quotes in your insights to justify the sentiment\n' +
      '   - Use the representativeQuotes from the sentiment analysis JSON\n' +
      '   - Format quotes like: stating <strong>"actual customer quote here"</strong>\n' +
      '   - This provides concrete evidence for why Agentforce assessed the sentiment the way it did\n' +
      '   - If declining sentiment, show before/after quotes to demonstrate the change\n' +
      '   - If mixed sentiment, show contrasting quotes for different themes\n' +
      '3. **LEVERAGE THE ADVANCED SENTIMENT ANALYSIS** - Use the sophisticated sentiment data provided above:\n' +
      '   - Cite specific relationship dynamics (formality shifts, response patterns)\n' +
      '   - Highlight critical findings from the sentiment analysis\n' +
      '   - Reference theme-specific sentiment (not just overall sentiment)\n' +
      '   - Quote emotional indicators and subtle signals detected\n' +
      '4. Combine emails and meetings into a SINGLE communication insight (e.g., "47 emails and 12 meetings" together)\n' +
      '5. Focus on revenue-generating activities (opportunities, deals) over generic activity counts\n' +
      '6. Highlight concerns (cases, closed-lost deals) but balance with wins\n' +
      '7. Only mention lack of activity if there are truly NO communications or opportunities\n\n' +
      '- Examples of ADVANCED sentiment-driven insights with ACTUAL EMAIL QUOTES:\n' +
      '  * "🎉 We successfully closed <strong>3 deals worth $4.2M</strong> in the last 90 days, demonstrating strong momentum and excellent execution with this customer."\n' +
      '  * "Advanced sentiment analysis reveals <strong>declining customer satisfaction</strong> over the past 90 days. Earlier emails stated <strong>"Really appreciate your quick response"</strong>, while recent messages show frustration: <strong>"This is the third time I\'ve had to follow up on this issue"</strong>. The shift from appreciation to frustration indicates growing relationship strain."\n' +
      '  * "Email analysis reveals <strong>mixed sentiment across different areas</strong>. The customer is enthusiastic about the product, writing <strong>"The new features are exactly what we needed"</strong>, but frustrated with support, stating <strong>"It took 5 days to get a response to a critical issue"</strong>. This shows we excel at product delivery but struggle with support responsiveness."\n' +
      '  * "Communication patterns show a <strong>concerning shift from collaborative to transactional language</strong>. Recent emails contain phrases like <strong>"As previously requested..."</strong> and <strong>"We are currently evaluating alternative solutions"</strong> - clear churn risk signals that require immediate executive attention."\n' +
      '  * "Customer engagement shows <strong>volatile sentiment with unresolved concerns</strong>. Three recent emails contained urgent language: <strong>"Need immediate attention on this"</strong>, <strong>"This is becoming a major blocker"</strong>, and <strong>"Management is questioning our investment"</strong>. These direct quotes indicate accumulated frustration and potential escalation."\n' +
      '  * "Email content reveals <strong>specific pain points requiring attention</strong>: Pricing flexibility (<strong>"The current pricing structure doesn\'t align with our usage patterns"</strong>), Implementation timelines (<strong>"We were promised a 30-day rollout but we\'re at day 60"</strong>), and Feature gaps (<strong>"This functionality was discussed during the sales process but isn\'t available"</strong>)."\n' +
      '  * "Relationship dynamics assessment shows <strong>diminishing engagement quality</strong>. Early emails were detailed and collaborative: <strong>"Let\'s schedule time to walk through the implementation plan together"</strong>. Recent emails are terse and directive: <strong>"Please confirm by EOD"</strong>. This shift suggests the customer feels unheard."\n' +
      '  * "Positive sentiment is evident in recent communications. The customer wrote: <strong>"Your team has been incredibly responsive"</strong>, <strong>"The implementation is going smoother than expected"</strong>, and <strong>"Really impressed with the level of support"</strong>. These quotes demonstrate genuine satisfaction and strong relationship health."\n' +
      '  * "<strong>36 open cases</strong> with <strong>6 being high priority</strong> suggests unresolved issues are accumulating, which could lead to customer frustration and <strong>potential churn risk</strong>."\n' +
      '- CRITICAL REQUIREMENT: When email data exists, you MUST include actual customer email quotes in at least ONE insight\n' +
      '- NEVER INCLUDE NUMERICAL SENTIMENT SCORES (like +0.8, -0.4, 0.7, etc.) - users have no context for these numbers\n' +
      '- DO NOT include raw sentiment scores, confidence percentages, or numerical sentiment values in insights\n' +
      '- Instead, USE ACTUAL QUOTES from emails (from representativeQuotes field) to provide concrete evidence of sentiment\n' +
      '- Use qualitative descriptions only: "positive sentiment", "declining satisfaction", "frustrated tone", etc.\n' +
      '- Format quotes properly with <strong> tags: <strong>"customer quote here"</strong>\n' +
      '- Quotes show readers WHY Agentforce assessed the sentiment the way it did - they are ESSENTIAL for credibility\n' +
      '- Reference the sophisticated findings from the sentiment analysis JSON (trajectories, dynamics, themes, quotes) but NOT the numerical scores\n' +
      '- Explain the business implication of each data point with real examples\n' +
      '- Celebrate wins prominently before discussing concerns\n\n' +
      'CRITICAL INSTRUCTIONS FOR RECOMMENDED ACTIONS:\n' +
      '- Provide 2-4 actions that are SPECIFIC, ACTIONABLE, and GROUNDED in the actual data\n' +
      '- DO NOT use generic templates - make each action unique and relevant to THIS account\n' +
      '- BASE ACTIONS ON THE ADVANCED SENTIMENT ANALYSIS FINDINGS:\n' +
      '  * If sentiment trajectory is declining, prioritize relationship repair\n' +
      '  * If critical findings were detected, address them urgently\n' +
      '  * If bifurcated sentiment exists, separate actions for positive vs negative areas\n' +
      '  * If formality/tone shifts detected, acknowledge and address the relationship change\n' +
      '- CRITICAL: DO NOT REPEAT EMAIL QUOTES in actions - quotes should only appear in insights\n' +
      '- Instead, REFERENCE the findings/sentiment/themes from insights without re-quoting\n' +
      '- Match urgency to both health status AND sentiment trajectory\n' +
      '- IMPORTANT: Return plain text with <strong> HTML tags for bold formatting (NOT markdown **)\n' +
      '- Use <strong></strong> HTML tags for important metrics, dollar amounts, timeframes, and action urgency words\n' +
      '- Examples of ADVANCED sentiment-based actions (NO QUOTES, just references to insights):\n' +
      '  * "Initiate an <strong>immediate executive intervention</strong> to address the <strong>repeated follow-up frustration</strong> identified in recent emails. The shift from appreciation to frustration requires senior leadership engagement to rebuild trust."\n' +
      '  * "Schedule separate conversations: First, celebrate the <strong>product success</strong> the customer expressed. Second, urgently address the <strong>support response time concerns</strong> with a dedicated CSM and implement <strong>24-hour response SLAs</strong>."\n' +
      '  * "Respond to the <strong>critical churn risk signal</strong> about evaluating alternatives by scheduling a strategic value review meeting <strong>within 48 hours</strong> with executive sponsorship to demonstrate ROI and renewal value."\n' +
      '  * "Address the <strong>relationship dynamic shift from collaborative to transactional</strong> by reaching out personally to understand what changed 3 weeks ago and rebuild the partnership approach."\n' +
      '  * "Capitalize on the <strong>highly positive sentiment</strong> about team responsiveness and support quality by scheduling an upsell conversation to discuss <strong>premium features and expansion opportunities</strong> while momentum is strong."\n' +
      '  * "Create an immediate action plan for the <strong>3 urgent blockers</strong> raised by the customer, focusing on the concerns about management questioning investment. Assign owners and provide <strong>daily progress updates</strong> until resolved."\n' +
      '  * "Implement <strong>bi-weekly executive business reviews</strong> to address the <strong>pricing structure concerns</strong> and <strong>feature availability gaps</strong> mentioned in recent communications. Focus on closing expectation gaps."\n' +
      '  * "Conduct a root-cause analysis of why <strong>3 active opportunities totaling $1.2M</strong> have stalled, addressing the <strong>pricing flexibility concerns</strong> raised. Propose a customized pricing model aligned with their usage patterns."\n' +
      '  * "Launch a proactive outreach campaign addressing the <strong>implementation timeline concerns</strong> about the delayed rollout. Provide a revised timeline with <strong>weekly checkpoints and accountability measures</strong>."\n' +
      '- DO NOT reference raw sentiment scores or abstract metrics in actions\n' +
      '- DO NOT repeat email quotes - reference themes, concerns, or praise generally\n' +
      '- Be prescriptive about WHAT to do, WHEN, and WHY (based on insights)\n' +
      '- Connect actions to the sentiment findings without duplicating quotes already shown in insights\n\n' +
      'Remember: Actions should reference the insights/findings but NOT repeat the email quotes. Keep actions focused on WHAT TO DO, not re-explaining WHY with the same quotes.';

    try {
      // Use the default OpenAI GPT-4o mini model
      String modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

      // Create generate text request
      aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
      request.modelName = modelName;

      // Create request body
      aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
      request.body = requestBody;
      requestBody.prompt = promptText;

      // Make request
      aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
      aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(
        request
      );

      // Extract the generated text from response
      if (response.Code200 != null && response.Code200.generation != null) {
        return response.Code200.generation.generatedText;
      } else {
        return buildFallbackResponse(contextData);
      }
    } catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
      System.debug('Einstein AI Error: ' + e.getMessage());
      // Return fallback response
      return buildFallbackResponse(contextData);
    } catch (Exception e) {
      System.debug('General Error: ' + e.getMessage());
      // Return fallback response
      return buildFallbackResponse(contextData);
    }
  }

  private static String buildFallbackResponse(String contextData) {
    // Basic fallback analysis if AI is unavailable
    return '{\n' +
      '  "healthStatus": "Moderate",\n' +
      '  "score": 50,\n' +
      '  "trend": "Stable",\n' +
      '  "keyInsights": ["AI analysis temporarily unavailable", "Manual review recommended", "Metrics available above"],\n' +
      '  "recommendedActions": ["Review engagement metrics manually", "Contact account team for insights"]\n' +
      '}';
  }

  private static void parseAIResponse(
    String aiResponse,
    AccountHealthAnalysis analysis
  ) {
    try {
      // Clean up response (remove markdown code blocks if present)
      String cleanedResponse = aiResponse.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7);
      }
      if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.substring(3);
      }
      if (cleanedResponse.endsWith('```')) {
        cleanedResponse = cleanedResponse.substring(
          0,
          cleanedResponse.length() - 3
        );
      }
      cleanedResponse = cleanedResponse.trim();

      // Parse JSON
      Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(
        cleanedResponse
      );

      analysis.healthStatus = (String) responseMap.get('healthStatus');
      analysis.score = ((Decimal) responseMap.get('score')).intValue();
      analysis.trend = (String) responseMap.get('trend');

      List<Object> insightsObj = (List<Object>) responseMap.get('keyInsights');
      analysis.keyInsights = new List<String>();
      for (Object insight : insightsObj) {
        analysis.keyInsights.add((String) insight);
      }

      List<Object> actionsObj = (List<Object>) responseMap.get(
        'recommendedActions'
      );
      analysis.recommendedActions = new List<String>();
      for (Object action : actionsObj) {
        analysis.recommendedActions.add((String) action);
      }
    } catch (Exception e) {
      System.debug('Error parsing AI response: ' + e.getMessage());
      System.debug('AI Response was: ' + aiResponse);
      analysis.healthStatus = 'Unknown';
      analysis.score = 50;
      analysis.trend = 'Stable';
      analysis.keyInsights = new List<String>{
        'Unable to parse AI response',
        'Manual review recommended'
      };
      analysis.recommendedActions = new List<String>{
        'Try refreshing the analysis'
      };
    }
  }
}
