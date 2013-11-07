//
//  VideoViewController.h
//  CloudReco
//
//  Created by Mac-4 on 11/07/13.
//
//

#import <UIKit/UIKit.h>

@interface VideoViewController : UIViewController<UIWebViewDelegate> {
    IBOutlet UIWebView *webView;
}
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withVideoUrl:(NSString *)_videoUrl;

@end
