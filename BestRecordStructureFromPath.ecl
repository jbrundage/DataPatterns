/***
 * Function macro that allows you to call BestRecordStructure knowing only its
 * path.  The path is examined to determine its underlying type, record
 * structure and (if necessary) other metadata information needed in order to
 * construct a DATASET declaration for it.  The dataset is then passed to the
 * BestRecordStructure() function macro for evaluation.
 *
 * For non-flat files, it is important that a record definition be available
 * in the file's metadata.  For just-sprayed files, this is commonly defined
 * in the first line of the file and furthermore that the "Record Structure
 * Present" option in the spray dialog box had been checked.
 *
 * Note that this function requires HPCC Systems version 6.4.0 or later.  It
 * leverages the dynamic record lookup capabilities added to that version and
 * described in https://hpccsystems.com/blog/file-layout-resolution-compile-time.
 *
 * @param   path            The full path to the file to profile; REQUIRED
 * @param   sampling        A positive integer representing a percentage of
 *                          the file to examine, which is useful when analyzing a
 *                          very large dataset and only an estimatation is
 *                          sufficient; valid range for this argument is
 *                          1-100; values outside of this range will be
 *                          clamped; OPTIONAL, defaults to 100 (which indicates
 *                          that the entire dataset will be analyzed)
 * @param   emitTransform   Boolean governing whether the function emits a
 *                          TRANSFORM function that could be used to rewrite
 *                          the dataset into the 'best' record definition;
 *                          OPTIONAL, defaults to FALSE.
 * @param   textOutput      Boolean governing the type of result that is
 *                          delivered by this function; if FALSE then a
 *                          recordset of STRINGs will be returned; if TRUE
 *                          then a dataset with a single STRING field, with
 *                          the contents formatted for HTML, will be
 *                          returned (this is the ideal output if the
 *                          intention is to copy the output from ECL Watch);
 *                          OPTIONAL, defaults to FALSE
 *
 * @return  A recordset defining the best ECL record structure for the data.
 *          If textOutput is FALSE (the default) then each record will contain
 *          one field declaration, and the list of declarations will be wrapped
 *          with RECORD and END strings; if the emitTransform argument was
 *          TRUE, there will also be a set of records that that comprise a
 *          stand-alone TRANSFORM function.  If textOutput is TRUE then only
 *          one record will be returned, containing an HTML-formatted string
 *          containing the new field declarations (and optionally the
 *          TRANSFORM); this is the ideal format if the intention is to copy
 *          the result from ECL Watch.
 */
EXPORT BestRecordStructureFromPath(path, sampling = 100, emitTransform = FALSE, textOutput = FALSE) := FUNCTIONMACRO
    IMPORT DataPatterns;
    IMPORT Std;

    // Function for gathering metadata associated with a file path
    LOCAL GetFileAttribute(STRING attr) := NOTHOR(Std.File.GetLogicalFileAttribute(path, attr));

    // Gather certain metadata about the given path
    LOCAL fileKind := GetFileAttribute('kind');
    LOCAL sep := GetFileAttribute('csvSeparate');
    LOCAL term := GetFileAttribute('csvTerminate');
    LOCAL quoteChar := GetFileAttribute('csvQuote');
    LOCAL escChar := GetFileAttribute('csvEscape');
    LOCAL headerLineCnt := GetFileAttribute('headerLength');

    // Dataset declaration for a delimited file
    LOCAL csvDataset := DATASET
        (
            path,
            RECORDOF(path, LOOKUP),
            CSV(HEADING(headerLineCnt), SEPARATOR(sep), TERMINATOR(term), QUOTE(quoteChar), ESCAPE(escChar))
        );

    // Dataset declaration for a flat file
    LOCAL flatDataset := DATASET
        (
            path,
            RECORDOF(path, LOOKUP),
            FLAT
        );

    // The returned value needs to be in a common format; the format here was
    // extracted from the DataPatterns.BestRecordStructure code
    LOCAL CommonResultRec :=
        #IF((BOOLEAN)textOutput)
            {STRING result__html}
        #ELSE
            {STRING s}
        #END;

    LOCAL RunBestRecordStructure(tempFile, _sampleSize, _emitTransform, _textOutput) := FUNCTIONMACRO
        LOCAL theResult := DataPatterns.BestRecordStructure(tempFile, _sampleSize, _emitTransform, _textOutput);

        RETURN PROJECT
            (
                theResult,
                TRANSFORM
                    (
                        CommonResultRec,
                        SELF := LEFT
                    )
            );
    ENDMACRO;

    LOCAL resultStructure := CASE
        (
            TRIM(fileKind, ALL),
            'flat'  =>  RunBestRecordStructure(flatDataset, sampling, emitTransform, textOutput),
            'csv'   =>  RunBestRecordStructure(csvDataset, sampling, emitTransform, textOutput),
            ''      =>  RunBestRecordStructure(csvDataset, sampling, emitTransform, textOutput),
            ERROR(DATASET([], CommonResultRec), 'Cannot run BestRecordStructure on file of kind "' + fileKind + '"')
        );

    RETURN resultStructure;
ENDMACRO;
