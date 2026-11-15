/**
 * @description Unit tests for WasteComplaintDuplicateService potential duplicate detection.
 */
@IsTest
private class WasteComplaintDuplicateServiceTest {

    @IsTest
    static void testCheckPotentialDuplicates() {
        Waste_Complaint__c wc = GreenTrackTestDataFactory.createComplaint(
            'Street Litter',
            'Household Waste',
            'Low',
            'East Zone'
        );

        Test.startTest();
        List<Waste_Complaint__c> dupes = WasteComplaintDuplicateService.checkPotentialDuplicates(
            'East Zone',
            'Household Waste',
            '100 Green Ave'
        );
        Test.stopTest();

        System.assert(!dupes.isEmpty(), 'Should detect existing active complaint in same area and type');
    }
}
