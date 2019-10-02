/*
 * Copyright (c) 2017, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


/*
 * DownloadTaskDelegate is utilized by JAHPAuthenticatingHTTPProtocol
 * to signal file download events and progress to the implementer (WebViewTab).
 */

#import <Foundation/Foundation.h>

@protocol DownloadTaskDelegate <NSObject>
- (void)didStartDownloadingFile;
- (void)didFinishDownloadingToURL:(NSURL*)location;
- (void)setProgress:(NSNumber *)pr;
@end

/*
 * DownloadHelper is utilized by JAHPQNSURLSessionDemux to move newly downloaded
 * files to our temporary "downloads" directory which is cleared on the first
 * download of the application life cycle.
 */

@interface DownloadHelper: NSObject
+ (void)deleteDownloadsDirectory;
+ (NSURL*)moveFileToDownloadsDirectory:(NSURL*)filePath withFilename:(NSString*)filename;
@end
