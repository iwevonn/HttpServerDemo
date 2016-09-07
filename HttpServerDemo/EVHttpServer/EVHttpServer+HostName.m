//
//  EVHttpServer+HostName.m
//  HttpServerDemo
//
//  Created by iwevon on 16/7/13.
//  Copyright © 2016年 iwevon. All rights reserved.
//

#import "EVHttpServer+HostName.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#include <net/if.h>

@implementation HTTPServer (HostName)

- (NSString*)hostName
{
    NSString *address = nil;
    struct ifaddrs *addrs;
    const struct ifaddrs *cursor;
    int error;
    error = getifaddrs(&addrs);
    
    if (error)
    {
        //NSLog(@"%s", gai_strerror(error));
    }
    for (cursor = addrs; cursor; cursor = cursor->ifa_next)
    {
        if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
        {
            NSString *ifa_name = [NSString stringWithUTF8String:cursor->ifa_name];
            if([@"en0" isEqualToString:ifa_name] ||
               [@"en1" isEqualToString:ifa_name])
            {
                address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
                break;
            }
        }
    }
    freeifaddrs(addrs);
    return address;
}



@end
