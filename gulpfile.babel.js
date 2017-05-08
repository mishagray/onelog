/**
 * Created by michaelgray on 5/8/17.
 */
import gulp from 'gulp';
import babel from 'gulp-babel';
import rm from 'gulp-rm';
import gutil from 'gulp-util';
import logger from 'gulp-logger';
import changed from 'gulp-changed';
import sourcemaps from 'gulp-sourcemaps';
import relativeSourcemapsSource from 'gulp-relative-sourcemaps-source';
import shell from 'gulp-shell';


gulp.task('default', ['build'], () => {});

gulp.task('build', ['babel'], () => {});


gulp.task('clean', () => gulp.src('dist/**/*', { read: false })
.pipe(rm()));

const DIST = 'dist';

gulp.task('babel', [], () => gulp.src(['src/**/*.js'])
.pipe(changed(DIST))
.pipe(logger({
	before: 'Starting Babel...',
	after: 'Babel complete!',
	beforeEach: 'babel:',
	display: 'rel',
	showChange: true,
}))
.pipe(sourcemaps.init())
.pipe(babel().on('error', gutil.log))
.pipe(relativeSourcemapsSource({ dest: 'dist' }))
.pipe(sourcemaps.write('.', { includeContent: false, sourceRoot: '../src' }))
.pipe(gulp.dest(DIST)));

gulp.task('prune', [],
	shell.task([
		'npm prune --development'], {}));