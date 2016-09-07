//
//  EVHttpServerConnection.m
//  HttpServerDemo
//
//  Created by iwevon on 16/7/13.
//  Copyright © 2016年 iwevon. All rights reserved.
//

#import "EVHttpServerConnection.h"
#import "HTTPMessage.h"
#import "MultipartMessageHeader.h"
#import "MultipartMessageHeaderField.h"
#import "HTTPDynamicFileResponse.h"

//Default file path
#define EVHTTPSERVERCONNECTION_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/website"]

@implementation EVHttpServerConnection

+(void)load
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *targetFilePath = EVHTTPSERVERCONNECTION_PATH;
    if (![fileManager fileExistsAtPath:targetFilePath])
    {
        [fileManager createDirectoryAtPath:targetFilePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark HTTP Request and Response
//Connection is disconnected
- (void) die
{
    if (isUploading)
    {
        isUploading = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:UPLOADISCONNECTED object:nil];
    }
    [super die];
}

- (BOOL) supportsMethod:(NSString *)method atPath:(NSString *)path
{
    //This is very important, if not this code, no response when uploading
    if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/index.html"])
        return YES;
    return [super supportsMethod:method atPath:path];
}

- (BOOL) expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    //Click on your Web page after uploading executed
    if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/index.html"])
    {
        NSString *contentType = [request headerField:@"Content-Type"];
        NSUInteger paramsSeparator = [contentType rangeOfString:@";"].location;
        if (paramsSeparator==NSNotFound || paramsSeparator>=contentType.length - 1)
            return NO;
        NSString *type = [contentType substringToIndex:paramsSeparator];
        if (![type isEqualToString:@"multipart/form-data"])
            return NO;
        
        NSArray *params = [[contentType substringFromIndex:paramsSeparator + 1] componentsSeparatedByString:@";"];
        for (NSString *param in params)
        {
            paramsSeparator = [param rangeOfString:@"="].location;
            if (paramsSeparator==NSNotFound || paramsSeparator>=param.length - 1)
                continue;
            
            NSString *paramName = [param substringWithRange:NSMakeRange(1, paramsSeparator - 1)];
            NSString *paramValue = [param substringFromIndex:paramsSeparator + 1];
            if ([paramName isEqualToString:@"boundary"])
                [request setHeaderField:@"boundary" value:paramValue];
        }
        if ([request headerField:@"boundary"]==nil)
            return NO;
        return YES;
    }
    return [super expectsRequestBodyFromMethod:method atPath:path];
}

- (NSObject<HTTPResponse> *) httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    //Web pages and upload initialization after the end of the list display uploaded files
    if ([method isEqualToString:@"GET"] || ([method isEqualToString:@"POST"] && [path isEqualToString:@"/index.html"]))
    {
        NSMutableString *fileHtml = [[NSMutableString alloc] initWithString:@""];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *targetFilePath = EVHTTPSERVERCONNECTION_PATH;
        NSArray *contents = [fileManager  contentsOfDirectoryAtPath:targetFilePath error:NULL];
        NSEnumerator *eumerator = [contents objectEnumerator];
        
        NSString *fileName = nil;
        while (fileName=[eumerator nextObject])
        {
            [fileHtml appendFormat:@"<a href=\"%@\"> %@ </a><br/>",fileName, [fileName lastPathComponent]];
        }
        
        if ([method isEqualToString:@"GET"] && [path isEqualToString:@"/"])
            path = @"index.html";
        
        
        NSString *templatePath = [[config documentRoot] stringByAppendingPathComponent:path];
        
        if (![fileManager fileExistsAtPath:templatePath]){
            //If the file is not in the Bundle to find the path specified in the
            templatePath = [targetFilePath stringByAppendingPathComponent:path];
        }
        
        NSDictionary *replacementDict = [NSDictionary dictionaryWithObject:fileHtml forKey:@"MyFiles"];
        fileHtml = nil;
        return [[HTTPDynamicFileResponse alloc] initWithFilePath:templatePath forConnection:self separator:@"%" replacementDictionary:replacementDict];
    }
    return [super httpResponseForMethod:method URI:path];
}

- (void) prepareForBodyWithSize:(UInt64)contentLength
{
    //Get the total length of the uploaded file
    uploadFileSize = contentLength;
    //Prepare parsing
    parser = [[MultipartFormDataParser alloc] initWithBoundary:[request headerField:@"boundary"] formEncoding:NSUTF8StringEncoding];
    parser.delegate = self;
}

- (void) processBodyData:(NSData *)postDataChunk
{
    //Get the current data stream
    [parser appendData:postDataChunk];
}

#pragma mark File Transfer Process(Start->Content->End)
- (void) processStartOfPartWithHeader:(MultipartMessageHeader *)header
{
    MultipartMessageHeaderField *disposition = [header.fields objectForKey:@"Content-Disposition"];
    NSString *fileName = [[disposition.params objectForKey:@"filename"] lastPathComponent];
    if (fileName==nil || [fileName isEqualToString:@""])
        return;
    
    NSString *uploadFilePath = [EVHTTPSERVERCONNECTION_PATH stringByAppendingPathComponent:fileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //Ready to write the file, if the file already exists Overwrite
    if (![fileManager createFileAtPath:uploadFilePath contents:nil attributes:nil])
    {
        return;
    }
    isUploading = YES;
    storeFile = [NSFileHandle fileHandleForWritingAtPath:uploadFilePath];
    NSDictionary *value = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:uploadFileSize], @"totalfilesize", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:UPLOADSTART object:nil userInfo:value];
}

- (void) processContent:(NSData *)data WithHeader:(MultipartMessageHeader *)header
{
    if (storeFile)
    {
        [storeFile writeData:data];
        CGFloat progress = (CGFloat)(data.length) / (CGFloat)uploadFileSize;
        NSDictionary *value = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:progress], @"progressvalue",[NSNumber numberWithInteger:data.length], @"cureentvaluelength", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:UPLOADING object:nil userInfo:value];
    }
}

- (void) processEndOfPartWithHeader:(MultipartMessageHeader *)header
{
    isUploading = NO;
    [storeFile closeFile];
    storeFile = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:UPLOADEND object:nil];
}

- (void) processPreambleData:(NSData *)data
{
    
}

- (void) processEpilogueData:(NSData *)data
{
    
}

@end
