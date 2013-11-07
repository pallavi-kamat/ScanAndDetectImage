/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "BaseViewController.h"
#import "CRQCARutils.h"

@implementation BaseViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    BOOL retVal = [[CRQCARutils getInstance] shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    return retVal;
}

@end
