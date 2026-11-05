import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../app_theme.dart';
import '../models/form_schema.dart';
import '../models/record.dart';
import '../state/app_state.dart';
import '../utils/date_fmt.dart';
import 'export_page.dart';
import 'patient_form_page.dart';
import 'patient_day_page.dart';
import 'settings_page.dart';

/// 首页：月历（有记录的日期打点：蓝=有创，绿=无创）+ 当天患者列表
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final day = state.selectedDay ?? DateTime.now();
    final forms = state.formsForDay(day);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '设置',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
        title: const Text('呼吸治疗工作记录'),
        actions: [
          IconButton(
            tooltip: '导出 PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportPage()),
            ),
          ),
          TextButton(onPressed: state.resetToToday, child: const Text('今天')),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _calendar(context, state),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        '${formatCnDate(day)} · ${forms.length} 位患者',
                        style: const TextStyle(
                          fontSize: 13,
                          color: kInkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const _Legend(kInvasive, '有创'),
                      const SizedBox(width: 10),
                      const _Legend(kNiv, '无创'),
                    ],
                  ),
                ),
                Expanded(child: _list(context, state, forms, day)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newForm(context, day),
        icon: const Icon(Icons.add),
        label: const Text('新建病历'),
      ),
    );
  }

  void _newForm(BuildContext context, DateTime day) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientFormPage(date: day)),
    );
  }

  Widget _calendar(BuildContext context, AppState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: TableCalendar<FormMetaBundle>(
        firstDay: DateTime(2000, 1, 1),
        lastDay: DateTime(DateTime.now().year + 3, 12, 31),
        focusedDay: state.focusedDay,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: '月'},
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (d) =>
            state.selectedDay != null && isSameDate(d, state.selectedDay!),
        eventLoader: state.eventsForDay,
        onDaySelected: (selected, focused) {
          state.selectDay(selected);
          state.setFocusedDay(focused);
        },
        onPageChanged: state.setFocusedDay,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          headerPadding: const EdgeInsets.symmetric(vertical: 4),
          titleTextStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: kInk,
          ),
          titleTextFormatter: (d, locale) => formatMonth(d),
          leftChevronIcon: const Icon(Icons.chevron_left, size: 20, color: kInkSoft),
          rightChevronIcon: const Icon(Icons.chevron_right, size: 20, color: kInkSoft),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontSize: 12, color: kInkSoft),
          weekendStyle: TextStyle(fontSize: 12, color: kInkSoft),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return const SizedBox.shrink();
            final types = state.typesForDay(day);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (types.contains(kTypeInvasive))
                  const _Dot(kInvasive),
                if (types.contains(kTypeNiv)) const _Dot(kNiv),
                if (types.isEmpty) const _Dot(kPrimary),
              ],
            );
          },
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          cellMargin: EdgeInsets.all(3),
          defaultTextStyle: TextStyle(fontSize: 14, color: kInk),
          weekendTextStyle: TextStyle(fontSize: 14, color: kInkSoft),
          todayDecoration: BoxDecoration(
            color: kPrimarySoft, shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            fontSize: 14, color: kPrimary, fontWeight: FontWeight.w600,
          ),
          selectedDecoration: BoxDecoration(
            color: kPrimary, shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    AppState state,
    List<PatientForm> forms,
    DateTime day,
  ) {
    if (forms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined, size: 40, color: kInkSoft),
            const SizedBox(height: 12),
            const Text('这一天还没有记录',
                style: TextStyle(fontSize: 14, color: kInkSoft)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _newForm(context, day),
              child: const Text('填写病历首页'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: forms.length,
      itemBuilder: (context, i) {
        final f = forms[i];
        final inv = state.pointCount(f.id, f.date, kTypeInvasive);
        final niv = state.pointCount(f.id, f.date, kTypeNiv);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: kCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: kDivider),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PatientDayPage(formId: f.id!)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        f.displayName,
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: kInk,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        [
                          if (f.data['sex'] != null) f.data['sex'].toString(),
                          if (f.data['age'] != null &&
                              f.data['age'].toString().isNotEmpty)
                            '${f.data['age']}岁',
                        ].join('  '),
                        style: const TextStyle(fontSize: 12, color: kInkSoft),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, size: 18, color: kInkSoft),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '床号 ${f.bedNo.isEmpty ? '—' : f.bedNo}　病历号 ${f.mrn.isEmpty ? '—' : f.mrn}',
                    style: const TextStyle(fontSize: 12, color: kInkSoft),
                  ),
                  if (f.data['diagnosis'] != null &&
                      f.data['diagnosis'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '诊断：${f.data['diagnosis']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (inv > 0) _CountChip(kInvasive, '有创 $inv 次'),
                      if (inv > 0 && niv > 0) const SizedBox(width: 8),
                      if (niv > 0) _CountChip(kNiv, '无创 $niv 次'),
                      if (inv == 0 && niv == 0)
                        const Text('尚未录入通气记录',
                            style: TextStyle(fontSize: 12, color: kInkSoft)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Dot(color),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(fontSize: 11, color: kInkSoft)),
        ],
      );
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.color, this.text);
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      );
}
