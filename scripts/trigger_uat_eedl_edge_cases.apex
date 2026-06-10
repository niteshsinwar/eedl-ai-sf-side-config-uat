Set<Id> uatEedlEdgeCaseOpportunityIds = new Set<Id>{
    '006fs000001Tv5iAAC',
    '006Ip000004Ad1IIAS',
    '006fs000001VYo2AAG',
    '006Ip000004AdcJIAS',
    '006fs000000Vbw9AAC',
    '006fs000000ifPFAAY',
    '006fs000000w7fSAAQ',
    '006fs000000jU1yAAE',
    '006fs000001P018AAC',
    '006fs0000010NgpAAE'
};

EEDLVerificationGateway.processOpportunities(uatEedlEdgeCaseOpportunityIds);
System.debug(LoggingLevel.INFO, 'Queued UAT EEDL edge case Opportunities: ' + uatEedlEdgeCaseOpportunityIds);
