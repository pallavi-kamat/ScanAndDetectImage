/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "CRQCARutils.h"
#import <QCAR/QCAR.h>
#import <QCAR/QCAR_iOS.h>
#import <QCAR/CameraDevice.h>
#import <QCAR/Renderer.h>
#import <QCAR/Tracker.h>
#import <QCAR/TrackerManager.h>
#import <QCAR/ImageTracker.h>
#import <QCAR/MarkerTracker.h>
#import <QCAR/VideoBackgroundConfig.h>
#import <QCAR/TargetFinder.h>
#import <QCAR/TargetSearchResult.h>

//extern QCARutils *qUtils; // singleton class
extern QCAR::DataSet* recoDataSet;

// ----------------------------------------------------------------------------
// Credentials for authenticating with the CloudReco service
// These are read-only access keys for accessing the image database
// specific to this sample application - the keys should be replaced
// by your own access keys. You should be very careful how you share
// your credentials, especially with untrusted third parties, and should
// take the appropriate steps to protect them within your application code
// ----------------------------------------------------------------------------
static const char* const kAccessKey = "3b02a8fdde4ec349eeaab0ddfb0915bd12aea849";
static const char* const kSecretKey = "bfd788125af7840a38ff70aa9a3e4594189ef8b0";

extern bool isActivityInPortraitMode, scanningMode;

@interface QCARutils(Private)
- (void)restoreCameraSettings;
@end

@implementation CRQCARutils
@synthesize lastScannedBook, deviceOrientationLock, lastTargetIDScanned;

#pragma mark - Public

// initialise QCARutils
- (id) init
{
    if ((self = [super init]) != nil)
    {
        isVisualSearchOn= NO;
    }
    return self;
}


// Return the CRQCARutils singleton, initing if necessary.  We instantiate this
// as soon as the app starts (in the app delegate), so it replaces the standard
// QCARutils object
+ (CRQCARutils *) getInstance
{
    if (qUtils == nil)
    {
        qUtils = [[CRQCARutils alloc] init];
    }
        
    return (CRQCARutils *)qUtils;
}

//  Determines if a UIViewController can autorotate depending on the orientation lock set
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    BOOL retVal = NO;
    
    CRQCARutils *utils = [CRQCARutils getInstance];
    
    if (utils.deviceOrientationLock == DeviceOrientationLockAuto)
    {
        //  Automatic orientation is enabled, rotate
        retVal = YES;
    }
    else if (utils.deviceOrientationLock == DeviceOrientationLockPortrait)
    {
        retVal = UIInterfaceOrientationIsPortrait(interfaceOrientation);
    }
    else if (utils.deviceOrientationLock == DeviceOrientationLockLandscape)
    {
        retVal = UIInterfaceOrientationIsLandscape(interfaceOrientation);
    }
    
    return retVal;
}

- (void)updateApplicationStatus:(status)newStatus
{
    if (newStatus != appStatus && APPSTATUS_ERROR != appStatus) {
        appStatus = newStatus;
        
        switch (appStatus) {
            case APPSTATUS_INIT_APP:
                NSLog(@"APPSTATUS_INIT_APP");
                // Initialise the application
                [self initApplication];
                [self updateApplicationStatus:APPSTATUS_INIT_QCAR];
                break;
                
            case APPSTATUS_INIT_QCAR:
                NSLog(@"APPSTATUS_INIT_QCAR");
                // Initialise QCAR
                [self performSelectorInBackground:@selector(initQCAR) withObject:nil];
                break;
                
            case APPSTATUS_INIT_TRACKER:
                NSLog(@"APPSTATUS_INIT_TRACKER");
                // Initialise the tracker
                if ([self initTracker] > 0) {
                    [self updateApplicationStatus: APPSTATUS_INIT_APP_AR];
                }
                break;
                
            case APPSTATUS_INIT_APP_AR:
                NSLog(@"APPSTATUS_INIT_APP_AR");
                // AR-specific initialisation
                [self initApplicationAR];
                
                // skip the loading of a DataSet for markers
                if (targetType != TYPE_FRAMEMARKERS)
                    [self updateApplicationStatus:APPSTATUS_LOAD_TRACKER];
                else
                    [self updateApplicationStatus:APPSTATUS_INITED];
                break;
                
            case APPSTATUS_LOAD_TRACKER:
                NSLog(@"APPSTATUS_LOAD_TRACKER");
                // Load tracker data
                [self performSelectorInBackground:@selector(loadTracker) withObject:nil];
                
                break;
                
            case APPSTATUS_INITED:
                NSLog(@"APPSTATUS_INITED");
                // Tasks for after QCAR inited but before camera starts running
                QCAR::onResume(); // ensure it's called first time in
                [self postInitQCAR];
                
                [self updateApplicationStatus:APPSTATUS_CAMERA_RUNNING];
                break;
                
            case APPSTATUS_CAMERA_RUNNING:
                NSLog(@"APPSTATUS_CAMERA_RUNNING");
                // Start the camera and tracking
                [self startCamera];
                videoStreamStarted = YES;
                break;
                
            case APPSTATUS_CAMERA_STOPPED:
                NSLog(@"APPSTATUS_CAMERA_STOPPED");
                // Stop the camera and tracking
                [self stopCamera];
                break;
                
            default:
                NSLog(@"updateApplicationStatus: invalid app status");
                break;
        }
    }
    
    if (APPSTATUS_ERROR == appStatus) {
        // Application initialisation failed, display an alert view
        UIAlertView *alert = nil;
        NSString *message = nil;
        NSString *title = nil;
        
        switch (errorCode) {
            case QCAR_ERRCODE_NO_NETWORK_CONNECTION:
                title = @"Network Unavailable";
                message = @"Please check your internet connection and try again."; 
                break;
            case QCAR_ERRCODE_NO_SERVICE_AVAILABLE:
                title = @"Service Unavailable";
                message = @"The cloud recognition service is unavailable, please try again later.";
                break;
            case QCAR::INIT_DEVICE_NOT_SUPPORTED:
                title = @"Error";
                message = @"Failed to initialize QCAR because this device is not supported.";
                break;
            case QCAR::INIT_ERROR:
            case QCAR_ERRCODE_INIT_TRACKER:
            case QCAR_ERRCODE_CREATE_DATASET:
            case QCAR_ERRCODE_LOAD_DATASET:
            case QCAR_ERRCODE_ACTIVATE_DATASET:
            case QCAR_ERRCODE_DEACTIVATE_DATASET:
            default:
                message = @"Application initialisation failed.";
                title = @"Error";
                break;
        }
        
        alert = [[UIAlertView alloc] initWithTitle:title
                                           message:message
                                          delegate:self
                                 cancelButtonTitle:@"OK"
                                 otherButtonTitles:nil];
        
        [alert show];
        [alert release];
    }
}

// discard resources
- (void)dealloc
{
    targetsList = nil;
    [lastScannedBook release];
    [super dealloc];
}

//////////////////////////////////////////////////////////////////////////////////
// Initialise the tracker [performed on a background thread]
- (int)initTracker
{
    int res = 0;
    
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* trackerBase = trackerManager.initTracker(QCAR::Tracker::IMAGE_TRACKER);
    // Set the visual search credentials:
    QCAR::TargetFinder* targetFinder = static_cast<QCAR::ImageTracker*>(trackerBase)->getTargetFinder();
    if (targetFinder == NULL)
    {
        NSLog(@"Failed to get target finder.");
        return 0;
    }
    
    NSLog(@"Successfully initialized ImageTracker.");
    res=1;
    return res;
}

- (void)loadTracker
{
    [self initVisualSearch];
}


////////////////////////////////////////////////////////////////////////////////
// Load the tracker data [performed on a background thread]
- (void)initVisualSearch
{
    NSLog(@"Initialize Visual Search in background thread");
    // Background thread must have its own autorelease pool
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
    if (imageTracker == NULL)
    {
        NSLog(@"Failed to load tracking data set because the ImageTracker has not been initialized.");
        
    }
    
    // Initialize visual search:
    QCAR::TargetFinder* targetFinder = imageTracker->getTargetFinder();
    if (targetFinder == NULL)
    {
        NSLog(@"Failed to get target finder.");
    }
    
    
    // Start initialization:
    if (targetFinder->startInit(kAccessKey, kSecretKey))
    {
        targetFinder->waitUntilInitFinished();
    }
    
    int resultCode = targetFinder->getInitState();
    if ( resultCode != QCAR::TargetFinder::INIT_SUCCESS)
    {
        appStatus = APPSTATUS_ERROR;
        if (resultCode == QCAR::TargetFinder::INIT_ERROR_NO_NETWORK_CONNECTION)
            errorCode = QCAR_ERRCODE_NO_NETWORK_CONNECTION;
        else if (resultCode == QCAR::TargetFinder::INIT_ERROR_SERVICE_NOT_AVAILABLE)
            errorCode = QCAR_ERRCODE_NO_SERVICE_AVAILABLE;
        
        NSLog(@"Failed to initialize target finder.");
    }
    
    // Continue execution on the main thread
    if (appStatus != APPSTATUS_ERROR)
        [self performSelectorOnMainThread:@selector(bumpAppStatus) withObject:nil waitUntilDone:NO];
    else
        [self performSelectorOnMainThread:@selector(updateApplicationStatus:) withObject:nil waitUntilDone:NO];
    
    [pool release];
}


////////////////////////////////////////////////////////////////////////////////
// Start capturing images from the camera
- (void)startCamera
{
    // Initialise the camera
    if (QCAR::CameraDevice::getInstance().init(activeCamera)) {
        // Configure video background
        [self configureVideoBackground];
        
        //// Select the default mode - given as example of how and where to set the Camera mode
        //if (QCAR::CameraDevice::getInstance().selectVideoMode(QCAR::CameraDevice::MODE_DEFAULT)) {
        
        // Start camera capturing
        if (QCAR::CameraDevice::getInstance().start()) {
            // Start the tracker
            QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
            
            QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(
                                                                                trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
            assert(imageTracker != 0);
            imageTracker->start();
            
            
            
            // Cache the projection matrix:
            const QCAR::CameraCalibration& cameraCalibration = QCAR::CameraDevice::getInstance().getCameraCalibration();
            projectionMatrix = QCAR::Tool::getProjectionGL(cameraCalibration, 2.0f, 2500.0f);
            
            
            // Start cloud based recognition if we are in scanning mode:
            if (scanningMode)
            {
                QCAR::TargetFinder* targetFinder = imageTracker->getTargetFinder();
                assert (targetFinder != 0);
                isVisualSearchOn = targetFinder->startRecognition();
            }
        }
        
        
        // Restore camera settings
        [self restoreCameraSettings];
    }
}

////////////////////////////////////////////////////////////////////////////////
// Toggle Visual Search

- (void) toggleVisualSearch:(BOOL)visualSearchOn
{
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(
                                                                        trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
    assert(imageTracker != 0);
    QCAR::TargetFinder* targetFinder = imageTracker->getTargetFinder();
    assert (targetFinder != 0);
    vsAutoControlEnabled = NO;
    if (visualSearchOn == NO)
    {
        targetFinder->startRecognition();
        isVisualSearchOn = YES;
    }
    else
    {
        targetFinder->stop();
        isVisualSearchOn = NO;
    }
}

////////////////////////////////////////////////////////////////////////////////
// Stop capturing images from the camera
- (void)stopCamera
{
    // Stop the tracker:
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(
                                                                        trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
    assert(imageTracker != 0);
    imageTracker->stop();
    
    // Stop cloud based recognition:
    QCAR::TargetFinder* targetFinder = imageTracker->getTargetFinder();
    assert (targetFinder != 0);
    isVisualSearchOn = !targetFinder->stop();
    
    QCAR::CameraDevice::getInstance().stop();
    QCAR::CameraDevice::getInstance().deinit();
}

////////////////////////////////////////////////////////////////////////////////
// Configure the video background
- (void)configureVideoBackground
{
    // Get the default video mode
    QCAR::CameraDevice& cameraDevice = QCAR::CameraDevice::getInstance();
    QCAR::VideoMode videoMode = cameraDevice.getVideoMode(QCAR::CameraDevice::MODE_DEFAULT);
    
    // Configure the video background
    QCAR::VideoBackgroundConfig config;
    config.mEnabled = true;
    config.mSynchronous = true;
    config.mPosition.data[0] = 0.0f;
    config.mPosition.data[1] = 0.0f;
    
    // Compare aspect ratios of video and screen.  If they are different
    // we use the full screen size while maintaining the video's aspect
    // ratio, which naturally entails some cropping of the video.
    // Note - screenRect is portrait but videoMode is always landscape,
    // which is why "width" and "height" appear to be reversed.
    float arVideo = (float)videoMode.mWidth / (float)videoMode.mHeight;
    float arScreen = viewSize.height / viewSize.width;
    
    int width;
    int height;
    
    if (isActivityInPortraitMode)
    {
        if (arVideo > arScreen)
        {
            // Video mode is wider than the screen.  We'll crop the left and right edges of the video
            config.mSize.data[0] = (int)viewSize.width;
            config.mSize.data[1] = (int)viewSize.width * arVideo;
            width = (int)viewSize.width;
            height = (int)viewSize.height;
        }
        else
        {
            // Video mode is taller than the screen.  We'll crop the top and bottom edges of the video.
            // Also used when aspect ratios match (no cropping).
            config.mSize.data[0] = (int)viewSize.height / arVideo;
            config.mSize.data[1] = (int)viewSize.height;
            width = (int)viewSize.height;
            height = (int)viewSize.width;
        }
        
    }
    else if (!isActivityInPortraitMode)
    {
        if (arVideo > arScreen)
        {
            // Video mode is wider than the screen.  We'll crop the left and right edges of the video
            config.mSize.data[0] = (int)viewSize.width * arVideo;
            config.mSize.data[1] = (int)viewSize.width;
            width = (int)viewSize.width;
            height = (int)viewSize.height;
        }
        else
        {
            // Video mode is taller than the screen.  We'll crop the top and bottom edges of the video.
            // Also used when aspect ratios match (no cropping).
            config.mSize.data[0] = (int)viewSize.height;
            config.mSize.data[1] = (int)viewSize.height / arVideo;
            width = (int)viewSize.height;
            height = (int)viewSize.width;
        }
    }
    
    
    // Calculate the viewport for the app to use when rendering.  This may or
    // may not be used, depending on the desired functionality of the app
    viewport.posX = ((width - config.mSize.data[0]) / 2) + config.mPosition.data[0];
    viewport.posY =  (((int)(height - config.mSize.data[1])) / (int) 2) + config.mPosition.data[1];
    viewport.sizeX = config.mSize.data[0];
    viewport.sizeY = config.mSize.data[1];
    
    // Set the config
    QCAR::Renderer::getInstance().setVideoBackgroundConfig(config);
    
    // Configure the video background
    QCAR::VideoBackgroundConfig config_get;
    config_get = QCAR::Renderer::getInstance().getVideoBackgroundConfig();
    NSLog(@"Video background get data %d %d", config_get.mSize.data[0], config_get.mSize.data[1]);
}


#pragma mark --- configuration methods ---
////////////////////////////////////////////////////////////////////////////////
// Load and Unload Data Set

- (BOOL)unloadDataSet:(QCAR::DataSet *)theDataSet
{
    BOOL success = NO;
    
    // Get the image tracker:
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
    
    if (imageTracker == NULL)
    {
        NSLog(@"Failed to unload tracking data set because the ImageTracker has not been initialized.");
        errorCode = QCAR_ERRCODE_INIT_TRACKER;
    }
    
    // Deinitialize visual search:
    QCAR::TargetFinder* finder = imageTracker->getTargetFinder();
    finder->deinit();
    
    return success;
}

#pragma mark - CloudReco

-(void)showUIAlertFromErrorCode:(int)code
{
    
    if (!isShowingAnAlertView)
    {
        
        NSString *title = nil;
        NSString *message = nil;
        
        if (code == QCAR::TargetFinder::UPDATE_ERROR_NO_NETWORK_CONNECTION)
        {
            title = @"Network Unavailable";
            message = @"Please check your internet connection and try again.";
        }
        else if (code == QCAR::TargetFinder::UPDATE_ERROR_REQUEST_TIMEOUT)
        {
            title = @"Request Timeout";
            message = @"The network request has timed out, please check your internet connection and try again.";
        }
        else if (code == QCAR::TargetFinder::UPDATE_ERROR_SERVICE_NOT_AVAILABLE)
        {
            title = @"Service Unavailable";
            message = @"The cloud recognition service is unavailable, please try again later.";
        }
        else if (code == QCAR::TargetFinder::UPDATE_ERROR_UPDATE_SDK)
        {
            title = @"Unsupported Version";
            message = @"The application is using an unsupported version of Vuforia.";
        }
        else if (code == QCAR::TargetFinder::UPDATE_ERROR_TIMESTAMP_OUT_OF_RANGE)
        {
            title = @"Clock Sync Error";
            message = @"Please update the date and time and try again.";
        }
        else if (code == QCAR::TargetFinder::UPDATE_ERROR_AUTHORIZATION_FAILED)
        {
            title = @"Authorization Error";
            message = @"The cloud recognition service access keys are incorrect or have expired.";
        }
        else if (code == QCAR::TargetFinder::UPDATE_ERROR_PROJECT_SUSPENDED)
        {
            title = @"Authorization Error";
            message = @"The cloud recognition service has been suspended.";
        }
        else if (code == QCAR::TargetFinder::UPDATE_ERROR_BAD_FRAME_QUALITY)
        {
            title = @"Poor Camera Image";
            message = @"The camera does not have enough detail, please try again later";
        }
        else
        {
            title = @"Unknown error";
            message = [NSString stringWithFormat:@"An unknown error has occurred (Code %d)", code];
        }
        
        //  Call the UIAlert on the main thread to avoid undesired behaviors
        dispatch_async( dispatch_get_main_queue(), ^{
            if (title && message)
            {
                UIAlertView *anAlertView = [[[UIAlertView alloc] initWithTitle:title
                                                                       message:message
                                                                      delegate:self
                                                             cancelButtonTitle:@"OK"
                                                             otherButtonTitles:nil] autorelease];
                anAlertView.tag = 42;
                [anAlertView show];
                isShowingAnAlertView = YES;
            }        
        });
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 42)
    {
        //  Do nothing, just want to avoid the exit() written on the super class
        isShowingAnAlertView = NO;
    }
    else
    {
        [super alertView:alertView clickedButtonAtIndex:buttonIndex];
    }
}

@end
