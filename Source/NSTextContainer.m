/* 
   NSTextContainer.m

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Jonathan Gapen <jagapen@smithlab.chem.wisc.edu>
   Date: 1999

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#import <AppKit/NSLayoutManager.h>
#import <AppKit/NSTextContainer.h>
#import <AppKit/NSTextStorage.h>
#import <AppKit/NSTextView.h>
#import <Foundation/NSGeometry.h>
#import <Foundation/NSNotification.h>

@interface NSTextContainer (TextViewObserver)
- (void) _textViewFrameChanged: (NSNotification*)aNotification;
@end

@implementation NSTextContainer (TextViewObserver)

- (void) _textViewFrameChanged: (NSNotification*)aNotification
{
  if (_observingFrameChanges)
    {
      id	textView;
      NSSize	newTextViewSize;
      NSSize	size;
      NSSize	inset;

      textView = [aNotification object];
      if (textView != _textView)
        {
	    NSDebugLog (@"NSTextContainer got notification for wrong View %@",
			textView);
	    return;
	}
      newTextViewSize = [textView frame].size;
      size = _containerRect.size;
      inset = [textView textContainerInset];

      if (_widthTracksTextView)
	{
	  size.width = MAX (newTextViewSize.width - (inset.width * 2.0), 0.0);
	}
      if (_heightTracksTextView)
	{
	  size.height = MAX (newTextViewSize.height - (inset.height * 2.0), 
			     0.0);
	}

      [self setContainerSize: size];
    }
}

@end /* NSTextContainer (TextViewObserver) */

@implementation NSTextContainer

+ (void) initialize
{
  if (self == [NSTextContainer class])
    {
      [self setVersion: 1];
    }
}

- (id) initWithContainerSize: (NSSize)aSize
{
  NSDebugLLog (@"NSText", @"NSTextContainer initWithContainerSize");
  _layoutManager = nil;
  _textView = nil;
  _containerRect.size = aSize;
  _lineFragmentPadding = 0.0;
  _observingFrameChanges = NO;
  _widthTracksTextView = NO;
  _heightTracksTextView = NO;

  return self;
}

- (void) dealloc
{
  if (_textView != nil)
    {
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc removeObserver: self
	  name: NSViewFrameDidChangeNotification
	  object: _textView];
      
      RELEASE (_textView);
    }
  [super dealloc];
}

- (void) setLayoutManager: (NSLayoutManager*)aLayoutManager
{
  /* The layout manager owns us - so he retains us and we don't retain 
     him. */
  _layoutManager = aLayoutManager;
}

- (NSLayoutManager*) layoutManager
{
  return _layoutManager;
}

- (void) replaceLayoutManager: (NSLayoutManager*)newLayoutManager
{
  if (newLayoutManager != _layoutManager)
    {
      id	textStorage = [_layoutManager textStorage];
      NSArray	*textContainers = [_layoutManager textContainers]; 
      unsigned	i, count = [textContainers count];

      [textStorage removeLayoutManager: _layoutManager];
      [textStorage addLayoutManager: newLayoutManager];
      [_layoutManager setTextStorage: nil];

      for (i = 0; i < count; i++)
	{
	  NSTextContainer	*container;

	  container = RETAIN ([textContainers objectAtIndex: i]);
	  [_layoutManager removeTextContainerAtIndex: i];
	  [newLayoutManager addTextContainer: container];
	  RELEASE (container);
	}
    }
}

- (void) setTextView: (NSTextView*)aTextView
{
  NSNotificationCenter *nc;
  BOOL informsLayoutManager = NO;

  nc = [NSNotificationCenter defaultCenter];
	  
  if (_textView)
    {
      informsLayoutManager = YES;
      [_textView setTextContainer: nil];
      [nc removeObserver: self  name: NSViewFrameDidChangeNotification 
	  object: _textView];
      /* NB: We do not set posts frame change notifications for the
	 text view to NO because there could be other observers for
	 the frame change notifications. */
    }

  ASSIGN (_textView, aTextView);

  if (aTextView != nil)
    {
      [_textView setTextContainer: self];
      if (_observingFrameChanges)
	{
	  [_textView setPostsFrameChangedNotifications: YES];
	  [nc addObserver: self
	      selector: @selector(_textViewFrameChanged:)
	      name: NSViewFrameDidChangeNotification
	      object: _textView];
	}
    }

  if (informsLayoutManager == YES)
    {
      [_layoutManager textContainerChangedTextView: self];
    }
}

- (NSTextView*) textView
{
  return _textView;
}

- (void) setContainerSize: (NSSize)aSize
{
  if (NSEqualSizes (_containerRect.size, aSize))
    {
      return;
    }

  _containerRect = NSMakeRect (0, 0, aSize.width, aSize.height);

  if (_layoutManager)
    {
      [_layoutManager textContainerChangedGeometry: self];
    }
}

- (NSSize) containerSize
{
  return _containerRect.size;
}

- (void) setWidthTracksTextView: (BOOL)flag
{
  NSNotificationCenter *nc;
  BOOL old_observing = _observingFrameChanges;

  _widthTracksTextView = flag;
  _observingFrameChanges = _widthTracksTextView | _heightTracksTextView;

  if (_textView == nil)
    return;

  if (_observingFrameChanges == old_observing)
    return;

  nc = [NSNotificationCenter defaultCenter];

  if (_observingFrameChanges)
    {      
      [_textView setPostsFrameChangedNotifications: YES];
      [nc addObserver: self
	  selector: @selector(_textViewFrameChanged:)
	  name: NSViewFrameDidChangeNotification
	  object: _textView];
    }
  else
    {
      [nc removeObserver: self name: NSViewFrameDidChangeNotification 
	  object: _textView];
    }
}

- (BOOL) widthTracksTextView
{
  return _widthTracksTextView;
}

- (void) setHeightTracksTextView: (BOOL)flag
{
  NSNotificationCenter *nc;
  BOOL old_observing = _observingFrameChanges;

  _heightTracksTextView = flag;
  _observingFrameChanges = _widthTracksTextView | _heightTracksTextView;
  if (_textView == nil)
    return;

  if (_observingFrameChanges == old_observing)
    return;

  nc = [NSNotificationCenter defaultCenter];

  if (_observingFrameChanges)
    {      
      [_textView setPostsFrameChangedNotifications: YES];
      [nc addObserver: self
	  selector: @selector(_textViewFrameChanged:)
	  name: NSViewFrameDidChangeNotification
	  object: _textView];
    }
  else
    {
      [nc removeObserver: self name: NSViewFrameDidChangeNotification 
	  object: _textView];
    }
}

- (BOOL) heightTracksTextView
{
  return _heightTracksTextView;
}

- (void) setLineFragmentPadding: (float)aFloat
{
  _lineFragmentPadding = aFloat;

  if (_layoutManager)
    [_layoutManager textContainerChangedGeometry: self];
}

- (float) lineFragmentPadding
{
  return _lineFragmentPadding;
}

- (NSRect) lineFragmentRectForProposedRect: (NSRect)proposedRect
			    sweepDirection: (NSLineSweepDirection)sweepDir
			 movementDirection: (NSLineMovementDirection)moveDir
			     remainingRect: (NSRect*)remainingRect;
{
  // line fragment rectangle simply must fit within the container rectangle
  *remainingRect = NSZeroRect;
  return NSIntersectionRect (proposedRect, _containerRect);
}

- (BOOL) isSimpleRectangularTextContainer
{
  // sub-classes may say no; this class always says yes
  return YES;
}

- (BOOL) containsPoint: (NSPoint)aPoint
{
  return NSPointInRect (aPoint, _containerRect);
}

@end /* NSTextContainer */

