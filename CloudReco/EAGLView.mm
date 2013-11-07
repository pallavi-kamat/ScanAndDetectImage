/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

// Subclassed from AR_EAGLView
#import "Transition3Dto2D.h"
#import "CRQCARutils.h"
#import "CloudRecoAppDelegate.h"
#import "TargetOverlayView.h"
#import "QCARHelper.h"

#import "EAGLView.h"
#import "Texture.h"
#include <QCAR/QCAR.h>
#include <QCAR/UpdateCallback.h>
#include <QCAR/CameraDevice.h>
#include <QCAR/Renderer.h>
#include <QCAR/Area.h>
#include <QCAR/Rectangle.h>
#include <QCAR/VideoBackgroundConfig.h>
#include <QCAR/Trackable.h>
#include <QCAR/Tool.h>
#include <QCAR/Tracker.h>
#include <QCAR/TrackerManager.h>
#include <QCAR/ImageTracker.h>
#include <QCAR/CameraCalibration.h>
#include <QCAR/ImageTarget.h>
#include <QCAR/DataSet.h>
#include <QCAR/TargetFinder.h>
#include <QCAR/TargetSearchResult.h>
#include <QCAR/ImageTargetResult.h>
#include <pthread.h>
#include <unistd.h>
#include <QCAR/QCAR.h>
#include <QCAR/QCAR_iOS.h>
#import "ShaderUtils.h"

#import <QuartzCore/QuartzCore.h>
#import "CRQCARutils.h"
#import "CloudRecoAppDelegate.h"
#import "BookOverlayPlane.h"
#import "ImagesManager.h"
#import "BooksManager.h"
#import "SampleMath.h"
#import "QCARHelper.h"


// ----------------------------------------------------------------------------
// Application Render States
// ----------------------------------------------------------------------------
static int RS_NORMAL = 0;
static int RS_TRANSITION_TO_2D = 1;
static int RS_TRANSITION_TO_3D = 2;
static int RS_SCANNING = 3;

// Whether the application is in scanning mode (or in content mode):
bool scanningMode = true;

// Time we last showed an error message:
double lastErrorMessageTime = 0;
int lastErrorCode = 0;

// Whether the cloud based reco was started:
bool vsStarted = false;


namespace {
    // Texture filenames
    const char* textureFilenames[] = {
        "mock_book_cover.png"
    };
    
    // Model scale factor
    float kXObjectScale = 400.0f;
    float kYObjectScale = 192;
    const float kZObjectScale = 3.0f;
    
    class VisualSearch_UpdateCallback : public QCAR::UpdateCallback {
        virtual void QCAR_onUpdate(QCAR::State& state);
    } qcarUpdate;
    
    void enterContentMode()
    {
        QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
        QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(
                                                                            trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
        assert(imageTracker != 0);
        QCAR::TargetFinder* targetFinder = imageTracker->getTargetFinder();
        assert (targetFinder != 0);
        
        // Stop visual search
        qUtils.isVisualSearchOn = !targetFinder->stop();
        
        // Remember we are in content mode:
        scanningMode = false;
    }
    
    
    void enterScanningMode()
    {
        QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
        QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(
                                                                            trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
        assert(imageTracker != 0);
        QCAR::TargetFinder* targetFinder = imageTracker->getTargetFinder();
        assert (targetFinder != 0);
        
        // Start visual search
        qUtils.isVisualSearchOn = targetFinder->startRecognition();
        
        // Clear all trackables created previously:
        targetFinder->clearTrackables();
        
        scanningMode = true;
    }
    
    BOOL trackingTIDSet;
    
    QCAR::Matrix44F modelViewMatrix;
}


// Indicates whether screen is in portrait (true) or landscape (false) mode
bool isActivityInPortraitMode = false;


////////////////////////////////////////////////////////////////////////////////
#pragma mark -
@implementation EAGLView

#pragma mark - Private

- (void)createContent:(QCAR::ImageTarget *)trackable
{
    //  Avoid querying the Book database when a bad target is found
    //  (Bad Targets are targets that are exists on the CloudReco database but
    //  not on our own book database)
    
    const char* trackableID = trackable->getUniqueTargetId();
    
    if (![[BooksManager sharedInstance] isBadTarget:trackableID])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kStartLoading" object:nil userInfo:nil];
        
        NSString *jsonFilename = [NSString stringWithUTF8String:trackable->getMetaData()];
        [[BooksManager sharedInstance] bookWithJSONFilename:jsonFilename withDelegate:self forTrackableID:trackableID];
    }
}

-(void)infoRequestDidFinishForBook:(Book *)theBook withTrackableID:(const char*)trackable byCancelling:(BOOL)cancelled
{
    if (theBook)
    {
        trackingTextureAvailable = NO;
        [[ImagesManager sharedInstance] imageForBook:theBook
                                        withDelegate:self];
    }
    else
    {
        if (NO == cancelled)
        {
            //  The trackable exists but it doesn't exist in our book database, so
            //  we'll mark that UniqueTargetId as a bad target
            [[BooksManager sharedInstance] addBadTargetId:trackable];
        }
        
        //  If theBook is nil, the loading UI would be shown forever and it
        //  won't scan again.  Send a notification to revert that state
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kStopLoading" object:nil userInfo:nil];
    }
}

-(void)imageRequestDidFinishForBook:(Book *)theBook withImage:(UIImage *)anImage byCancelling:(BOOL)cancelled;
{
    if (NO == cancelled)
    {
        if (nil != anImage)
        {
            // We now have the complete book (info and image), so enter content
            // mode.  We will return to scanning mode when the book view is
            // dismissed by the user
            enterContentMode();
            
            // Got an image for the book
            [[NSNotificationCenter defaultCenter] postNotificationName:@"kTargetFound" object:theBook userInfo:nil];
        }
        else {
            // Failed to get an image, but show the other information anyway (we
            // could take some different action in this case, if it were
            // considered an error, for example)
            
            // We now have the complete book (info and image), so enter content
            // mode.  We will return to scanning mode when the book view is
            // dismissed by the user
            enterContentMode();
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"kTargetFound" object:theBook userInfo:nil];
        }
    }
    else
    {
        // If the network operation was cancelled, the loading UI would be
        // shown forever and scanning will not resume.  Send a notification to
        // revert that state
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kStopLoading" object:theBook userInfo:nil];
    }
}

- (void)targetLost
{
    if (self.renderState == RS_NORMAL)
    {
        transitionDuration = 0.5f;
        //When the target is lost starts the 3d to 2d Transition
        self.renderState = RS_TRANSITION_TO_2D;
        startTransition = true;
    }
    
    isViewingTarget = NO;
}

- (void)targetReacquired
{
    if (self.renderState == RS_NORMAL && isShowing2DOverlay)
    {
        self.renderState = RS_TRANSITION_TO_3D;
        startTransition2Dto3D = true;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kTargetReacquired" object:nil userInfo:nil];
    }
}

#pragma mark - Properties

-(void)setRenderState:(int)newRenderState
{
    NSLog(@"#DEBUG setRenderState %d --> %d", renderState, newRenderState);
    renderState = newRenderState;
}

-(int)renderState
{
    return renderState;
}

#pragma mark - Public

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        kXObjectScale *= 1.25f;
        kYObjectScale *= 1.25f;
    }
    
    qUtils = [CRQCARutils getInstance];
    QCAR::registerCallback(&qcarUpdate);
    
	if (self)
    {
        // create list of textures we want loading - ARViewController will do this for us
        int nTextures = sizeof(textureFilenames) / sizeof(textureFilenames[0]);
        for (int i = 0; i < nTextures; ++i)
            [textureList addObject: [NSString stringWithUTF8String:textureFilenames[i]]];
    }
    
    framebufferLock = [[NSLock alloc] init];
    
    // Screen size:
    // Width and Height are swapped due to AR view is being shown in Landscape mode
    QCAR::Vec2F screenSize;
    screenSize.data[0] = qUtils.viewSize.height;
    screenSize.data[1] = qUtils.viewSize.width;
    
    // Reset global variables:
    scanningMode = true;
    
    //  CloudReco variables
    trackingTextureAvailable = NO;
    isViewingTarget = NO;
    
    return self;
}

- (void)enterScanningMode
{
    enterScanningMode();
    isViewingTarget = NO;
    self.renderState = RS_SCANNING;
    isShowing2DOverlay = NO;
}

- (CGRect) rectForAR
{
    CGRect retVal = CGRectZero;
    
    retVal = CGRectMake(0, 0, self.frame.size.width * .6, self.frame.size.width * .6);
    retVal.origin.x = (self.frame.size.width - retVal.size.width) / 2;
    retVal.origin.y = (self.frame.size.height - retVal.size.height) / 2;
    
    return retVal;
}

- (BOOL)isPointInsideAROverlay:(CGPoint)aPoint
{
    BOOL retVal = NO;
    
    CGRect arRect = [self rectForAR];
    
    if (CGRectContainsPoint(arRect, aPoint))
    {
        retVal = YES;
    }
        
    return retVal;
}

- (void)setOverlayLayer:(CALayer *)overlayLayer {
    
    UIImage* image = nil;
    
    UIGraphicsBeginImageContext(overlayLayer.frame.size);
    {
        [overlayLayer renderInContext: UIGraphicsGetCurrentContext()];
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    // Get the inner CGImage from the UIImage wrapper
    CGImageRef cgImage = image.CGImage;
    
    // Get the image size
    NSInteger width = CGImageGetWidth(cgImage);
    NSInteger height = CGImageGetHeight(cgImage);
    
    // Record the number of channels
    NSInteger channels = CGImageGetBitsPerPixel(cgImage)/CGImageGetBitsPerComponent(cgImage);
    
    // Generate a CFData object from the CGImage object (a CFData object represents an area of memory)
    CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    
    unsigned char* pngData = new unsigned char[width * height * channels];
    const int rowSize = width * channels;
    const unsigned char* pixels = (unsigned char*)CFDataGetBytePtr(imageData);
    
    // Copy the row data from bottom to top
    for (int i = 0; i < height; ++i) {
        memcpy(pngData + rowSize * i, pixels + rowSize * (height - 1 - i), width * channels);
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, QCAR::requiresAlpha() ? 0.0f : 1.0f);
    
    if (!trackingTIDSet) {
        glGenTextures(1, &tID);
    }
    
    glBindTexture(GL_TEXTURE_2D, tID);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA_EXT, GL_UNSIGNED_BYTE, (GLvoid*)pngData);
    
    trackingTIDSet = YES;
    trackingTextureAvailable = YES;
    
    delete[] pngData;
    CFRelease(imageData);
    
    self.renderState = RS_NORMAL;
}

- (void)dealloc
{
    [framebufferLock release];
    [super dealloc];
}

- (void)initRendering
{
    [super initRendering];
    
    transition3Dto2D = new Transition3Dto2D(qUtils.viewSize.width, qUtils.viewSize.height, isActivityInPortraitMode);
    transition3Dto2D->initializeGL(shaderProgramID);

    transition2Dto3D = new Transition3Dto2D(qUtils.viewSize.width, qUtils.viewSize.height, isActivityInPortraitMode);
    transition2Dto3D->initializeGL(shaderProgramID);

    self.renderState = RS_NORMAL;
    
    transitionDuration = 0.5f;
    trackableSize = QCAR::Vec2F(0.0f, 0.0f);
    
    renderingInited = YES;
}

- (void) setup3dObjects
{
    for (int i=0; i < [textures count]; i++)
    {
        Object3D *obj3D = [[Object3D alloc] init];
        
        obj3D.numVertices = sizeof(planeVertices) / sizeof(planeVertices[0]); // 12
        obj3D.vertices = planeVertices;
        obj3D.normals = planeNormals;
        obj3D.texCoords = planeTexcoords;
        
        obj3D.numIndices = sizeof(planeIndices) / sizeof(planeIndices[0]); // 6
        obj3D.indices = planeIndices;
        
        obj3D.texture = [textures objectAtIndex:i];
        
        [objects3D addObject:obj3D];
        [obj3D release];
    }
}


// called after QCAR is initialised but before the camera starts
- (void) postInitQCAR
{
    // TBD
    // Camera instance have to be initialised to get the appropriate values from configureVideoBackground
    QCAR::CameraDevice::getInstance().init();
    [qUtils configureVideoBackground];
    
    const QCAR::CameraCalibration& cameraCalibration = QCAR::CameraDevice::getInstance().getCameraCalibration();
    projectionMatrix = QCAR::Tool::getProjectionGL(cameraCalibration, 2.0f, 2500.0f);
    
    QCAR::CameraDevice::getInstance().deinit();
    // Here we could make a QCAR::setHint call to set the maximum
    // number of simultaneous targets
    // QCAR::setHint(QCAR::HINT_MAX_SIMULTANEOUS_IMAGE_TARGETS, 2);
    
}

// modify renderFrameQCAR here if you want a different 3D rendering model
////////////////////////////////////////////////////////////////////////////////
// Draw the current frame using OpenGL
//
// This method is called by QCAR when it wishes to render the current frame to
// the screen.
//
// *** QCAR will call this method on a single background thread ***
- (void)renderFrameQCAR
{
    [framebufferLock lock];
    [self setFramebuffer];
    
    if (qUtils.orientationChanged)
    {
        UIWindow* window = [UIApplication sharedApplication].keyWindow;
        
        QCAR::Vec2F screenSize;
        if (qUtils.orientation == UIInterfaceOrientationPortrait)
        {
            screenSize.data[0] = window.frame.size.width;
            screenSize.data[1] = window.frame.size.height;
            QCAR::onSurfaceChanged(qUtils.viewSize.width, qUtils.viewSize.height);
            QCAR::setRotation(QCAR::ROTATE_IOS_90);
            
            isActivityInPortraitMode = YES;
        }
        else if (qUtils.orientation == UIInterfaceOrientationPortraitUpsideDown)
        {
            screenSize.data[0] = window.frame.size.width;
            screenSize.data[1] = window.frame.size.height;
            QCAR::onSurfaceChanged(qUtils.viewSize.width, qUtils.viewSize.height);
            QCAR::setRotation(QCAR::ROTATE_IOS_270);
            
            isActivityInPortraitMode = YES;
        }
        else if (qUtils.orientation == UIInterfaceOrientationLandscapeLeft)
        {
            screenSize.data[0] = window.frame.size.height;
            screenSize.data[1] = window.frame.size.width;
            QCAR::onSurfaceChanged(qUtils.viewSize.height, qUtils.viewSize.width);
            QCAR::setRotation(QCAR::ROTATE_IOS_180);
            
            isActivityInPortraitMode = NO;
        }
        else if (qUtils.orientation == UIInterfaceOrientationLandscapeRight)
        {
            screenSize.data[0] = window.frame.size.height;
            screenSize.data[1] = window.frame.size.width;
            QCAR::onSurfaceChanged(qUtils.viewSize.height, qUtils.viewSize.width);
            QCAR::setRotation(1);
            
            isActivityInPortraitMode = NO;
        }
        
        if ([qUtils appStatus]>=APPSTATUS_INITED)
        {
            [qUtils configureVideoBackground];
        }
        
        // Cache the projection matrix:
        const QCAR::CameraCalibration& cameraCalibration = QCAR::CameraDevice::getInstance().getCameraCalibration();
        qUtils.projectionMatrix = QCAR::Tool::getProjectionGL(cameraCalibration, 2.0f, 2500.0f);
        qUtils.orientationChanged=false;
    }
    
    
    // Clear colour and depth buffers
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Render video background and retrieve tracking state
    QCAR::State state = QCAR::Renderer::getInstance().begin();
    QCAR::Renderer::getInstance().drawVideoBackground();
    
    // NSLog(@"active trackables: %d", state.getNumActiveTrackables());
    
    if (QCAR::GL_11 & qUtils.QCARFlags) {
        glEnable(GL_TEXTURE_2D);
        glDisable(GL_LIGHTING);
        glEnableClientState(GL_VERTEX_ARRAY);
        glEnableClientState(GL_NORMAL_ARRAY);
        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    }
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_DEPTH_TEST);
    // We must detect if background reflection is active and adjust the culling direction.
    // If the reflection is active, this means the pose matrix has been reflected as well,
    // therefore standard counter clockwise face culling will result in "inside out" models.
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    if(QCAR::Renderer::getInstance().getVideoBackgroundConfig().mReflection == QCAR::VIDEO_BACKGROUND_REFLECTION_ON)
        glFrontFace(GL_CW);  //Front camera
    else
        glFrontFace(GL_CCW);   //Back camera
    
    // Did we find any trackables this frame?
    if (state.getNumTrackableResults() > 0)
    {
        // Get the trackable:
        trackableResult = state.getTrackableResult(0);
        modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(trackableResult->getPose());
        
        // The target:
        const QCAR::Trackable& trackable = trackableResult->getTrackable();
        assert(trackable.getType() == QCAR::Trackable::IMAGE_TARGET);
        
        // Get the size of the ImageTarget
        QCAR::ImageTargetResult *imageResult = (QCAR::ImageTargetResult *)trackableResult;
        QCAR::Vec2F targetSize = imageResult->getTrackable().getSize();
        trackableSize.data[0] = targetSize.data[0];
        trackableSize.data[1] = targetSize.data[1];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            trackableSize.data[0] *= 1.25f;
            trackableSize.data[1] *= 1.25f;
        }
        
        QCAR::ImageTarget* imageTargetTrackable = (QCAR::ImageTarget*)&trackable;
        NSString *uniqueTargetId = [NSString stringWithUTF8String:imageTargetTrackable->getUniqueTargetId()];
        
        // If the last scanned book is different from the one it's scanning now
        // and no network operation is active, then generate texture again
        if (![[CRQCARutils getInstance].lastTargetIDScanned isEqualToString:uniqueTargetId] && NO == [[BooksManager sharedInstance] isNetworkOperationInProgress])
        {
            [CRQCARutils getInstance].lastTargetIDScanned = uniqueTargetId;
            [self createContent:imageTargetTrackable];
        }
        else
        {
            int targetIndex = 0;
            Object3D *obj3D = [objects3D objectAtIndex:targetIndex];
            
            if (!isViewingTarget && trackingTextureAvailable)
            {
                [self targetReacquired];
            }
            
            isViewingTarget = YES;
            
            if (trackingTextureAvailable)
            {
                if (self.renderState == RS_NORMAL) {
                    QCAR::Matrix44F modelViewProjection;
                    
                    ShaderUtils::translatePoseMatrix(0.0f, 0.0f, kZObjectScale, &modelViewMatrix.data[0]);
                    ShaderUtils::scalePoseMatrix(kXObjectScale, kYObjectScale, kZObjectScale, &modelViewMatrix.data[0]);
                    ShaderUtils::multiplyMatrix(&qUtils.projectionMatrix.data[0], &modelViewMatrix.data[0], &modelViewProjection.data[0]);
                    
                    glUseProgram(shaderProgramID);
                    
                    glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)obj3D.vertices);
                    glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)obj3D.normals);
                    glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)obj3D.texCoords);
                    
                    glEnableVertexAttribArray(vertexHandle);
                    glEnableVertexAttribArray(normalHandle);
                    glEnableVertexAttribArray(textureCoordHandle);
                    
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, tID);
                    glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (const GLfloat*)&modelViewProjection.data[0]);
                    glDrawElements(GL_TRIANGLES, obj3D.numIndices, GL_UNSIGNED_SHORT, (const GLvoid*)obj3D.indices);
                    
                    
                    ShaderUtils::checkGlError("EAGLView renderFrameQCAR");
                }
                else if (self.renderState == RS_TRANSITION_TO_3D) {
                    if (startTransition2Dto3D)
                    {
                        transitionDuration = 0.5f;
                        
                        //Starts the Transition
                        transition2Dto3D->startTransition(transitionDuration, true, true);
                        //Initialize control state variables
                        startTransition2Dto3D = false;
                    }
                    else
                    {
                        //Checks if the transitions has not finished
                        if (!reportedFinished2Dto3D)
                        {
                            //Renders the transition
                            transition2Dto3D->render(qUtils.projectionMatrix, trackableResult->getPose(), trackableSize, tID);
                            
                            // check if transition is finished
                            if (transition2Dto3D->transitionFinished())
                            {
                                //updates current renderState when the transition is finished
                                // to go back to normal rendering
                                startTransition2Dto3D = false;
                                self.renderState = RS_NORMAL;
                                isShowing2DOverlay = NO;
                            }
                        }
                    }
                }
            }
        }
        
        glDisable(GL_BLEND);
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
    }
    else
    { // There is no trackable target
        if (self.renderState == RS_TRANSITION_TO_2D) {
            if (startTransition) {
                NSLog(@"#DEBUG Starting transition");
                //Starts the Transition
                transition3Dto2D->startTransition(transitionDuration, false, true);
                
                //Initialize control state variables
                startTransition = false;
                reportedFinished = false;
            } else {
                //Checks if the transitions has not finished
                if (!reportedFinished) {
                    
                    //Renders the transition
                    transition3Dto2D->render(qUtils.projectionMatrix, trackableResult->getPose(), trackableSize, tID );
                    
                    // check if transition is finished
                    if (transition3Dto2D->transitionFinished() && !reportedFinished) {
                        isShowing2DOverlay = YES;
                        NSLog(@"#DEBUG Finished transition");
                        startTransition = false;
                        
                        self.renderState = RS_NORMAL;
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"kTargetLost" object:nil userInfo:nil];
                    }
                }
            }
        }
        
        if (isViewingTarget) { // This means there was a target but we can't find it anymore
            isViewingTarget = NO;
            
            // This needs to be called on main thread to make sure the thread doesn't die before the timer is called
            dispatch_async(dispatch_get_main_queue(), ^{
                [self targetLost];
            });
        }
    }
    
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    
    glDisableVertexAttribArray(vertexHandle);
    glDisableVertexAttribArray(normalHandle);
    glDisableVertexAttribArray(textureCoordHandle);
    
    
    QCAR::Renderer::getInstance().end();
    
    [self presentFramebuffer];
    [framebufferLock unlock];
}

/////////////////////////////////////////////////////////////////
//
- (void)deleteFramebuffer
{
    [framebufferLock lock];
    
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }
        
        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }
        
        if (depthRenderbuffer) {
            glDeleteRenderbuffers(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
    
    [framebufferLock unlock];
}


////////////////////////////////////////////////////////////////////////////////
// Callback function called by the tracker when each tracking cycle has finished
void VisualSearch_UpdateCallback::QCAR_onUpdate(QCAR::State& state)
{
    // Get the tracker manager:
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    
    // Get the image tracker:
    QCAR::ImageTracker* imageTracker = static_cast<QCAR::ImageTracker*>(trackerManager.getTracker(QCAR::Tracker::IMAGE_TRACKER));
    
    // Get the target finder:
    QCAR::TargetFinder* finder = imageTracker->getTargetFinder();
    
    // Check if there are new results available:
    const int statusCode = finder->updateSearchResults();
    if (statusCode < 0)
    {
        // Show a message if we encountered an error:
        [[CRQCARutils getInstance] showUIAlertFromErrorCode:statusCode];
    }
    else if (statusCode == QCAR::TargetFinder::UPDATE_RESULTS_AVAILABLE)
    {
        
        // Iterate through the new results:
        for (int i = 0; i < finder->getResultCount(); ++i)
        {
            const QCAR::TargetSearchResult* result = finder->getResult(i);
            
            // Check if this target is suitable for tracking:
            if (result->getTrackingRating() > 0)
            {
                // Create a new Trackable from the result:
                QCAR::Trackable* newTrackable = finder->enableTracking(*result);
                if (newTrackable != 0)
                {
                    QCAR::ImageTarget* imageTargetTrackable = (QCAR::ImageTarget*)newTrackable;
                    
                    //  Avoid entering on ContentMode when a bad target is found
                    //  (Bad Targets are targets that are exists on the CloudReco database but not on our
                    //  own book database)
                    if (![[BooksManager sharedInstance] isBadTarget:imageTargetTrackable->getUniqueTargetId()])
                    {
                        NSLog(@"Successfully created new trackable '%s' with rating '%d'.",
                              newTrackable->getName(), result->getTrackingRating());
                    }
                }
                else
                {
                    NSLog(@"Failed to create new trackable.");
                }
            }
        }
    }
}

@end
