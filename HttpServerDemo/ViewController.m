//
//  ViewController.m
//  HttpServerDemo
//
//  Created by iwevon on 16/7/13.
//  Copyright © 2016年 iwevon. All rights reserved.
//  参考 https://github.com/alimysoyang/InAppWebHTTPServer

#import "ViewController.h"

#import "HTTPServer.h"
#import "EVHttpServer+HostName.h"
#import "EVHttpServerConnection.h"

#define GBUnit 1073741824
#define MBUnit 1048576
#define KBUnit 1024


@interface ViewController ()
{
    UInt64 currentDataLength;
}
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) HTTPServer *httpserver;
@property (strong, nonatomic) UIProgressView *progressView;     //upload progress
@property (strong, nonatomic) UILabel *lbHTTPServer;
@property (strong, nonatomic) UILabel *lbFileSize;                      //Total size of uploaded file
@property (strong, nonatomic) UILabel *lbCurrentFileSize;           //The size of the current upload

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self initViews];
    [self initHttpserver];
    [self addHttpServerObserver];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    
    [_httpserver stop];
    currentDataLength = 0;
    [_progressView setHidden:YES];
    [_progressView setProgress:0.0];
    [_lbFileSize setText:@""];
    [_lbCurrentFileSize setText:@""];
    [self removeHttpServerObserver];
}

#pragma mark - HttpServer Function


- (void) initViews {
    
    _lbHTTPServer = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 50.0, 300.0, 80.0)];
    [_lbHTTPServer setBackgroundColor:[UIColor clearColor]];
    [_lbHTTPServer setFont:[UIFont boldSystemFontOfSize:14.0]];
    [_lbHTTPServer setLineBreakMode:NSLineBreakByWordWrapping];
    [_lbHTTPServer setNumberOfLines:4];
    [self.view addSubview:_lbHTTPServer];
    
    _lbFileSize = [[UILabel alloc] initWithFrame:CGRectMake(250.0, 135.0, 60.0, 20.0)];
    [_lbFileSize setBackgroundColor:[UIColor clearColor]];
    [_lbFileSize setFont:[UIFont boldSystemFontOfSize:13.0]];
    [self.view addSubview:_lbFileSize];
    
    _lbCurrentFileSize = [[UILabel alloc] initWithFrame:CGRectMake(188.0, 135.0, 60.0, 20.0)];
    [_lbCurrentFileSize setBackgroundColor:[UIColor clearColor]];
    [_lbCurrentFileSize setFont:[UIFont boldSystemFontOfSize:13.0]];
    [_lbCurrentFileSize setTextAlignment:NSTextAlignmentRight];
    [self.view addSubview:_lbCurrentFileSize];
    
    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    [_progressView setFrame:CGRectMake(10.0, 160.0, 300.0, 20.0)];
    [_progressView setHidden:YES];
    [self.view addSubview:_progressView];
    
    currentDataLength = 0;
}

- (void)initHttpserver {
    
    _httpserver = [[HTTPServer alloc] init];
    [_httpserver setType:@"_http._tcp."];
    [_httpserver setPort:16918];
    NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"website"];
    [_httpserver setDocumentRoot:webPath];
    [_httpserver setConnectionClass:[EVHttpServerConnection class]];
}

- (void) startServer {
    
    NSError *error;
    if ([_httpserver start:&error])
    {
        NSString *tip = @"[Uploaded file name can not contain Chinese and spaces]";
        [_lbHTTPServer setText:[NSString stringWithFormat:@"Started HTTP Server\n%@\n http://%@:%hu",tip, [_httpserver hostName], [_httpserver listeningPort]]];
    }
    else
    {
        NSLog(@"Error Started HTTP Server:%@", error);
    }
}


- (void) uploadWithStart:(NSNotification *) notification {
    
    UInt64 fileSize = [(NSNumber *)[notification.userInfo objectForKey:@"totalfilesize"] longLongValue];
    __block NSString *showFileSize = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if (fileSize>GBUnit)
            showFileSize = [[NSString alloc] initWithFormat:@"/%.1fG", (CGFloat)fileSize / (CGFloat)GBUnit];
        if (fileSize>MBUnit && fileSize<=GBUnit)
            showFileSize = [[NSString alloc] initWithFormat:@"/%.1fMB", (CGFloat)fileSize / (CGFloat)MBUnit];
        else if (fileSize>KBUnit && fileSize<=MBUnit)
            showFileSize = [[NSString alloc] initWithFormat:@"/%lliKB", fileSize / KBUnit];
        else if (fileSize<=KBUnit)
            showFileSize = [[NSString alloc] initWithFormat:@"/%lliB", fileSize];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_lbFileSize setText:showFileSize];
            [_progressView setHidden:NO];
        });
    });
    showFileSize = nil;
}

- (void) uploadWithEnd:(NSNotification *) notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        currentDataLength = 0;
        [_progressView setHidden:YES];
        [_progressView setProgress:0.0];
        [_lbFileSize setText:@""];
        [_lbCurrentFileSize setText:@""];
    });
}

- (void) uploadWithDisconnect:(NSNotification *) notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        currentDataLength = 0;
        [_progressView setHidden:YES];
        [_progressView setProgress:0.0];
        [_lbFileSize setText:@""];
        [_lbCurrentFileSize setText:@""];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Information" message:@"Upload data interrupt!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        alert = nil;
    });
}

- (void) uploading:(NSNotification *)notification {
    
    float value = [(NSNumber *)[notification.userInfo objectForKey:@"progressvalue"] floatValue];
    currentDataLength += [(NSNumber *)[notification.userInfo objectForKey:@"cureentvaluelength"] intValue];
    __block NSString *showCurrentFileSize = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if (currentDataLength>GBUnit)
            showCurrentFileSize = [[NSString alloc] initWithFormat:@"%.1fG", (CGFloat)currentDataLength / (CGFloat)GBUnit];
        if (currentDataLength>MBUnit && currentDataLength<=GBUnit)
            showCurrentFileSize = [[NSString alloc] initWithFormat:@"%.1fMB", (CGFloat)currentDataLength / (CGFloat)MBUnit];
        else if (currentDataLength>KBUnit && currentDataLength<=MBUnit)
            showCurrentFileSize = [[NSString alloc] initWithFormat:@"%lliKB", currentDataLength / KBUnit];
        else if (currentDataLength<=KBUnit)
            showCurrentFileSize = [[NSString alloc] initWithFormat:@"%lliB", currentDataLength];
        dispatch_async(dispatch_get_main_queue(), ^{
            _progressView.progress += value;
            [_lbCurrentFileSize setText:showCurrentFileSize];
        });
    });
    showCurrentFileSize = nil;
}


#pragma mark HttpServer Notification

- (void)addHttpServerObserver {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadWithStart:) name:UPLOADSTART object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploading:) name:UPLOADING object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadWithEnd:) name:UPLOADEND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadWithDisconnect:) name:UPLOADISCONNECTED object:nil];
    [self startServer];
}


- (void)removeHttpServerObserver {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UPLOADSTART object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UPLOADING object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UPLOADEND object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UPLOADISCONNECTED object:nil];
}


@end
