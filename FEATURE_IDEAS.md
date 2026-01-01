# Feature Ideas & Quality of Life Improvements

## High Priority Features

### 1. **Progress Tracking & Completion**
- **Mark sections as complete**: Add checkboxes or completion markers to highlights/notes
- **Progress percentage**: Show overall progress based on completed sections
- **Last worked on date**: Display when you last opened/worked on a project
- **Completion status**: Visual indicators (e.g., green checkmarks) for finished sections

### 2. **Pattern Navigation & Bookmarks**
- **Bookmarks**: Quick jump to important sections (e.g., "Cast on", "Decrease section")
- **Page thumbnails**: Sidebar or bottom bar with page thumbnails for quick navigation
- **Jump to page**: Quick navigation dialog to jump to specific page numbers
- **Recent positions**: Remember last viewed position per project (you already have scrollOffsetY - could enhance this)

### 3. **Enhanced Counter Features**
- **Counter templates**: Save common counter setups (e.g., "Sweater pattern" with row counter, stitch counter, repeat counter)
- **Counter groups**: Organize counters into groups (e.g., "Body", "Sleeves", "Collar")
- **Counter history**: Undo/redo for counter changes
- **Counter presets**: Quick-add buttons for common patterns (e.g., "Add row counter", "Add repeat counter")
- **Linked counters**: When one counter reaches max, automatically increment another (e.g., rows → rounds)

### 4. **Yarn & Materials Tracking**
- **Yarn inventory**: Track yarn colors, brands, weights, and amounts used
- **Yarn photos**: Attach photos to yarn entries for visual reference
- **Materials list**: Keep track of needles, hooks, stitch markers, etc.
- **Yarn calculator**: Estimate yarn needed based on gauge

### 5. **Photo Documentation**
- **Progress photos**: Take and attach photos to projects to track progress over time
- **Photo timeline**: View photos chronologically to see project evolution
- **Photo annotations**: Add notes to photos (e.g., "After 10 rows", "Before blocking")
- **Photo gallery**: Quick access to all project photos

## Medium Priority Features

### 6. **Pattern Search & Text Recognition**
- **Search in PDF**: Search for specific text within the pattern (if PDF has text layer)
- **OCR for scanned patterns**: Extract text from image-based PDFs for searching
- **Highlight search results**: Jump to and highlight search matches

### 7. **Stitch Reference Guide**
- **Built-in stitch library**: Quick reference for common stitches/abbreviations
- **Custom stitch notes**: Add your own stitch definitions and notes
- **Stitch calculator**: Calculate increases/decreases needed for shaping
- **Gauge calculator**: Calculate gauge and adjust pattern accordingly

### 8. **Size & Measurement Tracking**
- **Multiple sizes**: Track which size you're making (XS, S, M, L, etc.)
- **Measurement tracking**: Log measurements as you work (e.g., chest, length, sleeve)
- **Size comparison**: Compare your measurements to pattern requirements
- **Adjustment notes**: Document any modifications you make

### 9. **Enhanced Highlighting**
- **Highlight categories**: Organize highlights by type (e.g., "Important", "Questions", "Modifications")
- **Highlight labels**: Add text labels to highlights
- **Highlight search**: Filter highlights by color or category
- **Highlight export**: Export highlights as a summary document

### 10. **Better Note Organization**
- **Note categories**: Categorize notes (e.g., "Questions", "Modifications", "Tips")
- **Note templates**: Pre-filled note templates for common scenarios
- **Note search**: Search through all notes in a project
- **Note checklist**: Convert notes to checklists for step-by-step tracking

### 11. **Statistics & Analytics**
- **Time analytics**: 
  - Average session time
  - Total time per project
  - Time spent per week/month
  - Time breakdown by project
- **Progress charts**: Visual charts showing progress over time
- **Activity log**: Timeline of when you worked on projects

### 12. **Project Organization**
- **Project tags**: Tag projects (e.g., "WIP", "Finished", "Gift", "For me")
- **Project folders**: Organize projects into folders/categories
- **Project status**: Mark projects as "Planning", "In Progress", "On Hold", "Finished"
- **Project search**: Search projects by name, tags, or content
- **Sort options**: Sort projects by name, date created, last worked on, time spent

## Quality of Life Improvements

### 13. **UI/UX Enhancements**
- **Dark mode optimization**: Ensure all colors work well in dark mode
- **Zoom controls**: Better zoom in/out controls for PDF viewing
- **Pinch to zoom**: Enhanced pinch-to-zoom gestures
- **Full-screen mode**: Hide UI elements for distraction-free viewing
- **Customizable UI**: Let users choose which UI elements to show/hide
- **Haptic feedback**: Add haptic feedback for counter increments, timer start/stop
- **Accessibility**: VoiceOver support, larger text options, high contrast mode

### 14. **Performance & Reliability**
- **Auto-save improvements**: More frequent auto-saves (you already have periodic saves)
- **Backup/restore**: Export project data for backup
- **Crash recovery**: Better recovery if app crashes
- **Large PDF handling**: Optimize for very large pattern files
- **Offline support**: Ensure all features work offline

### 15. **Sharing & Export**
- **Export project summary**: Generate a summary of progress, time, notes
- **Share progress**: Share progress photos or notes with others
- **Export highlights**: Export highlighted sections as a separate document
- **Print support**: Print pattern with annotations

### 16. **Notifications & Reminders**
- **Work reminders**: "Haven't worked on this project in a while" notifications
- **Pattern reminders**: Set reminders for specific pattern steps (e.g., "Decrease every 4 rows")
- **Timer notifications**: Notifications when timer reaches certain milestones

### 17. **Quick Actions**
- **Siri Shortcuts**: "Start knitting timer", "Add counter"
- **Widgets**: Home screen widgets showing project progress, timer
- **Quick actions**: 3D Touch/Haptic Touch quick actions
- **Today extension**: Widget showing current project status

### 18. **Pattern-Specific Features**
- **Chart support**: Better support for knitting charts (if patterns include them)
- **Multiple pattern formats**: Support for other formats (images, text files)
- **Pattern comparison**: Compare different versions of the same pattern
- **Pattern annotations**: Pre-annotate patterns with common modifications

### 19. **Social & Community Features** (Optional)
- **Pattern sharing**: Share your annotated patterns with others
- **Community patterns**: Browse patterns shared by others
- **Progress sharing**: Share progress on social media

### 20. **Advanced Timer Features**
- **Multiple timers**: Track time for different aspects (e.g., "Knitting" vs "Finishing")
- **Timer sessions**: Track individual work sessions with start/end times
- **Timer goals**: Set time goals (e.g., "Work 2 hours this week")
- **Timer history**: View timer history per project

## Implementation Suggestions

### Quick Wins (Easy to implement, high impact)
2. ✅ **Project status** - Add status field (Planning, In Progress, On Hold, Finished)
3. ✅ **Counter templates** - Save/load counter configurations
4. ✅ **Bookmarks** - Simple bookmark system with page numbers
5. ✅ **Progress percentage** - Calculate based on completed highlights/sections
6. ✅ **Search projects** - Add search bar to project list
7. ✅ **Sort projects** - Add sort options (name, date, time spent)
8. ✅ **Haptic feedback** - Add to counter buttons and timer controls

### Medium Effort (Moderate complexity, good value)
1. **Photo documentation** - Camera integration, photo storage
2. **Yarn tracking** - New model and views for yarn inventory
3. **Enhanced highlighting** - Categories, labels, search
4. **Statistics dashboard** - Charts and analytics
5. **Pattern search** - PDF text extraction and search

### Long-term Features (Complex, high value)
1. **Cloud sync** - iCloud or other cloud storage
2. **OCR for scanned patterns** - Text recognition
3. **Stitch reference guide** - Comprehensive stitch library
4. **Chart support** - Special handling for knitting charts
5. **Widgets & Shortcuts** - iOS integration features

## User Workflow Considerations

Think about common workflows:
- **Starting a new project**: Load pattern → Set up counters → Start timer
- **Working on project**: View pattern → Track progress → Take notes → Update counters
- **Finishing project**: Mark complete → Add final photos → Export summary
- **Returning to project**: Quick access → See last position → Resume timer

Each feature should enhance these workflows without adding friction.

