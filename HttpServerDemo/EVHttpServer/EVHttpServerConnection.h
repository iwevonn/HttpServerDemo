//
//  EVHttpServerConnection.h
//  HttpServerDemo
//
//  Created by iwevon on 16/7/13.
//  Copyright © 2016年 iwevon. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import "HTTPConnection.h"
#import "MultipartFormDataParser.h"

#define UPLOADSTART @"uploadstart"
#define UPLOADING @"uploading"
#define UPLOADEND @"uploadend"
#define UPLOADISCONNECTED @"uploadisconnected"

@interface EVHttpServerConnection : HTTPConnection<MultipartFormDataParserDelegate>
{
    BOOL isUploading;                         //Is not being performed Upload
    MultipartFormDataParser *parser;    //
    NSFileHandle *storeFile;                  //Storing uploaded files
    UInt64 uploadFileSize;                     //The total size of the uploaded file
}

@end
