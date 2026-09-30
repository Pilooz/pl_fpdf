/*******************************************************************************
* Script: run_putstream_tests_simple.sql
* Description: Regression tests for p_putstream(BLOB), which writes an image
*              stream into the document.
*              Does not require utPLSQL - uses basic PL/SQL.
*
* Usage:
*   PL/SQL Developer: open in a SQL Window and press F8.
*   SQL*Plus:         SET SERVEROUTPUT ON, then run the script.
*
*   The script contains no SQL*Plus commands, so it runs unchanged in both.
*   Anonymous blocks are separated by '/' on its own line.
*
* Why the loop is tested outside the package:
*   p_putstream is private, and the only caller is the image path, which
*   fetches through URIFactory and therefore needs a network ACL a plain
*   schema does not have. Blocks 1 and 2 run the two loop forms side by side
*   over a controlled BLOB, so the boundary and the chunk-size behaviour are
*   measured directly rather than inferred from a generated file.
*
* Author: Maxwell da Silva Oliveira <maxwbh@gmail.com>
* Date: 2026-09-10
*******************************************************************************/


/*******************************************************************************
* 1. The loop boundary
*
* The original test is `while offset < length`. When the last chunk begins
* exactly at the final byte, the loop ends without reading it: the stream is
* short by one byte while /Length in the dictionary still promises the full
* count. A 2001-byte stream is the smallest case that shows it with a 2000-byte
* chunk.
*******************************************************************************/
declare
  l_blob   blob;
  l_buf    raw(2000);
  l_amount integer;
  l_offset integer;
  l_read   integer;
  l_len    integer;
  l_ok     pls_integer := 0;
  l_fail   pls_integer := 0;
begin
  dbms_output.put_line('== 1. Loop boundary');

  dbms_lob.createtemporary(l_blob, true);
  for i in 1 .. 2001 loop
    dbms_lob.writeappend(l_blob, 1, hextoraw('41'));
  end loop;
  l_len := dbms_lob.getlength(l_blob);

  -- the original form
  l_read   := 0;
  l_offset := 1;
  while l_offset < l_len loop
    l_amount := 2000;
    dbms_lob.read(l_blob, l_amount, l_offset, l_buf);
    l_read   := l_read + l_amount;
    l_offset := l_offset + l_amount;
  end loop;

  if l_read = l_len then
    dbms_output.put_line('   [FAIL] the original form read all ' || l_len
                         || ' bytes - the defect did not reproduce');
    l_fail := l_fail + 1;
  else
    dbms_output.put_line('   [OK]   the original form read ' || l_read
                         || ' of ' || l_len || ' bytes, as expected');
    l_ok := l_ok + 1;
  end if;

  -- the corrected form
  l_read   := 0;
  l_offset := 1;
  while l_offset <= l_len loop
    l_amount := 2000;
    dbms_lob.read(l_blob, l_amount, l_offset, l_buf);
    l_read   := l_read + l_amount;
    l_offset := l_offset + l_amount;
  end loop;

  if l_read = l_len then
    dbms_output.put_line('   [OK]   the corrected form read all ' || l_len
                         || ' bytes');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] the corrected form read ' || l_read
                         || ' of ' || l_len);
    l_fail := l_fail + 1;
  end if;

  dbms_lob.freetemporary(l_blob);
  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    dbms_output.put_line('   [FAIL] ' || sqlerrm);
end;
/


/*******************************************************************************
* 2. The chunk size is IN OUT
*
* dbms_lob.read returns in the amount parameter what it actually read. If the
* variable is initialized once instead of being set on every pass, a short read
* becomes the size of every read that follows.
*******************************************************************************/
declare
  l_blob   blob;
  l_buf    raw(2000);
  l_amount integer;
  l_ok     pls_integer := 0;
  l_fail   pls_integer := 0;
begin
  dbms_output.put_line('== 2. Chunk size is IN OUT');

  dbms_lob.createtemporary(l_blob, true);
  for i in 1 .. 500 loop
    dbms_lob.writeappend(l_blob, 1, hextoraw('41'));
  end loop;

  l_amount := 2000;
  dbms_lob.read(l_blob, l_amount, 1, l_buf);

  if l_amount = 500 then
    dbms_output.put_line('   [OK]   after a short read the amount holds 500, '
                         || 'not the 2000 it was given');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] amount came back as ' || l_amount);
    l_fail := l_fail + 1;
  end if;

  dbms_lob.freetemporary(l_blob);
  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    dbms_output.put_line('   [FAIL] ' || sqlerrm);
end;
/


/*******************************************************************************
* 3. Why the stream is emitted as hexadecimal
*
* The document is assembled as a CLOB and turned into a BLOB at the end with
* dbms_lob.convertToBlob, so anything written into it makes a round trip
* through the database character set.
*
* This block sends the 256 byte values down both routes, using public calls
* only, and compares what comes back:
*
*   - as reinterpreted characters (utl_raw.cast_to_varchar2), which is the
*     obvious way to keep a stream binary, and
*   - as hexadecimal, which is what the procedure now emits.
*
* Measured on AL32UTF8: 256 bytes go in through the first route and 422 come
* out. Hexadecimal is ASCII, so it is unaffected. That is the whole reason for
* the encoding, and this block is what keeps the reason checkable.
*******************************************************************************/
declare
  l_src     raw(256);
  l_blob    blob;
  l_txt     varchar2(4000);
  l_charset varchar2(60);
  l_bytes   pls_integer;
  l_ok      pls_integer := 0;
  l_fail    pls_integer := 0;

  function round_trip(p_text in varchar2) return blob is
    l_c clob;
    l_b blob;
    i pls_integer := 1;
    o pls_integer := 1;
    g pls_integer := 0;
    w pls_integer := 0;
  begin
    dbms_lob.createtemporary(l_c, true);
    dbms_lob.writeappend(l_c, length(p_text), p_text);
    dbms_lob.createtemporary(l_b, true);
    dbms_lob.convertToBlob(l_b, l_c, dbms_lob.getlength(l_c), i, o,
                           dbms_lob.default_csid, g, w);
    dbms_lob.freetemporary(l_c);
    return l_b;
  end round_trip;
begin
  dbms_output.put_line('== 3. Why the stream is hexadecimal');

  select value into l_charset
    from nls_database_parameters
   where parameter = 'NLS_CHARACTERSET';
  dbms_output.put_line('   NLS_CHARACTERSET = ' || l_charset);

  l_src := null;
  for i in 0 .. 255 loop
    l_src := utl_raw.concat(l_src, hextoraw(to_char(i, 'FM0X')));
  end loop;

  -- route 1: reinterpreted characters
  l_blob  := round_trip(utl_raw.cast_to_varchar2(l_src));
  l_bytes := dbms_lob.getlength(l_blob);
  dbms_output.put_line('   as characters:  256 bytes in, ' || l_bytes
                       || ' bytes out');
  if l_bytes = 256 and utl_raw.compare(dbms_lob.substr(l_blob, 256, 1), l_src) = 0 then
    dbms_output.put_line('   [INFO] this database round-trips raw bytes '
                         || 'faithfully - single-byte character set');
  else
    dbms_output.put_line('   [OK]   raw bytes do not survive, which is why the '
                         || 'stream is not written that way');
    l_ok := l_ok + 1;
  end if;
  dbms_lob.freetemporary(l_blob);

  -- route 2: hexadecimal, which is what p_putstream emits
  l_txt   := rawtohex(l_src);
  l_blob  := round_trip(l_txt);
  l_bytes := dbms_lob.getlength(l_blob);
  dbms_output.put_line('   as hexadecimal: ' || length(l_txt)
                       || ' characters in, ' || l_bytes || ' bytes out');
  if l_bytes = length(l_txt)
     and utl_raw.compare(utl_raw.cast_to_raw(rawtohex(l_src)),
                         dbms_lob.substr(l_blob, l_bytes, 1)) = 0 then
    dbms_output.put_line('   [OK]   hexadecimal survives the round trip '
                         || 'unchanged');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] hexadecimal did not survive - the encoding '
                         || 'assumption does not hold here');
    l_fail := l_fail + 1;
  end if;
  dbms_lob.freetemporary(l_blob);

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    dbms_output.put_line('   [FAIL] ' || sqlerrm);
end;
/


/*******************************************************************************
* 4. The package still builds a document
*
* p_putstream is on the output path for every document, so this confirms the
* change did not break generation itself.
*******************************************************************************/
declare
  l_pdf  blob;
  l_ok   pls_integer := 0;
  l_fail pls_integer := 0;
begin
  dbms_output.put_line('== 4. Document generation');

  PL_FPDF.Reset;
  PL_FPDF.Init('P', 'mm', 'A4');
  PL_FPDF.AddPage;
  PL_FPDF.SetFont('Arial', 'B', 16);
  PL_FPDF.Cell(0, 10, 'p_putstream', 0, 1, 'C');
  l_pdf := PL_FPDF.OutputBlob;

  if l_pdf is not null and dbms_lob.getlength(l_pdf) > 0 then
    dbms_output.put_line('   [OK]   document generated, '
                         || dbms_lob.getlength(l_pdf) || ' bytes');
    l_ok := l_ok + 1;
  else
    dbms_output.put_line('   [FAIL] OutputBlob returned an empty LOB');
    l_fail := l_fail + 1;
  end if;

  dbms_output.put_line('   --- ' || l_ok || ' ok, ' || l_fail || ' failed');
exception
  when others then
    dbms_output.put_line('   [FAIL] ' || sqlerrm);
end;
/
