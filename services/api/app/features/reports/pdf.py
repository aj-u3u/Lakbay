from io import BytesIO
from html import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import CondPageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from app.features.reports.schemas import TripReportSummaryResponse


def build_trip_report_pdf(report: TripReportSummaryResponse) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=0.7 * inch,
        leftMargin=0.7 * inch,
        topMargin=0.6 * inch,
        bottomMargin=0.6 * inch,
    )
    styles = getSampleStyleSheet()
    story = [
        Paragraph(f"Lakbay Trip Report: {_pdf_text(report.trip.title)}", styles["Title"]),
        Paragraph(f"Generated at: {report.generated_at.isoformat()}", styles["Normal"]),
        Spacer(1, 12),
    ]

    _add_trip_overview(story, report, styles)
    _add_destinations(story, report, styles)
    _add_itinerary(story, report, styles)
    _add_tasks(story, report, styles)
    _add_route(story, report, styles)
    _add_expenses(story, report, styles)
    _add_members(story, report, styles)

    doc.build(story)
    return buffer.getvalue()


def _add_heading(story: list, text: str, styles) -> None:
    story.extend([Spacer(1, 10), Paragraph(text, styles["Heading2"]), Spacer(1, 4)])


def _add_trip_overview(story: list, report: TripReportSummaryResponse, styles) -> None:
    _add_heading(story, "Trip Overview", styles)
    trip = report.trip
    data = [
        ["Status", trip.status],
        ["Dates", _date_range(trip.start_date, trip.end_date)],
        ["Traveler count", str(trip.traveler_count)],
        ["Total budget", _money(trip.total_budget)],
        ["Estimated total cost", _money(trip.estimated_total_cost)],
    ]

    if trip.description:
        data.append(["Description", trip.description])
    if trip.notes:
        data.append(["Notes", trip.notes])

    _add_key_value_table(story, data)


def _add_destinations(story: list, report: TripReportSummaryResponse, styles) -> None:
    _add_heading(story, "Destinations", styles)

    if not report.destinations:
        story.append(Paragraph("No destinations were saved for this trip.", styles["Normal"]))
        return

    data = [["Order", "Destination"]]
    data.extend(
        [str(destination.stop_order), destination.name]
        for destination in report.destinations
    )
    _add_table(story, data)


def _add_itinerary(story: list, report: TripReportSummaryResponse, styles) -> None:
    _add_heading(story, "Itinerary Schedule", styles)

    if not report.itinerary_days:
        story.append(Paragraph("No itinerary schedule was saved for this trip.", styles["Normal"]))
        return

    for day in report.itinerary_days:
        story.append(Paragraph(f"Day {day.day_number}: {_pdf_text(day.title)}", styles["Heading3"]))
        if day.summary:
            story.append(Paragraph(_pdf_text(day.summary), styles["Normal"]))

        if not day.activities:
            story.append(Paragraph("No activities listed.", styles["Normal"]))
            continue

        data = [["Order", "Time", "Activity", "Estimated Cost"]]
        data.extend(
            [
                str(activity.activity_order),
                activity.time or "",
                activity.title,
                _money(activity.estimated_cost),
            ]
            for activity in day.activities
        )
        _add_table(story, data)


def _add_route(story: list, report: TripReportSummaryResponse, styles) -> None:
    _add_heading(story, "Route Summary", styles)

    if report.route is None:
        story.append(Paragraph("No saved route summary is available.", styles["Normal"]))
        return

    route = report.route
    data = [
        ["Travel mode", route.travel_mode],
        ["Provider", route.route_provider],
        ["Estimated", "Yes" if route.is_estimated else "No"],
        ["Total distance", f"{route.total_distance_km} km"],
        ["Total duration", f"{route.total_duration_minutes} minutes"],
    ]
    _add_key_value_table(story, data)

    if route.stops:
        stops = [["Order", "Stop"]]
        stops.extend([str(stop.order), stop.name] for stop in route.stops)
        _add_table(story, stops)


def _add_tasks(story: list, report: TripReportSummaryResponse, styles) -> None:
    _add_heading(story, "Group Tasks", styles)
    if not report.tasks:
        story.append(Paragraph("No group tasks were saved for this trip.", styles["Normal"]))
        return

    data = [["Task", "Status", "Due Date"]]
    data.extend(
        [task.title, task.status.title(), task.due_date.isoformat() if task.due_date else ""]
        for task in report.tasks
    )
    _add_table(story, data)


def _add_expenses(story: list, report: TripReportSummaryResponse, styles) -> None:
    story.append(CondPageBreak(2 * inch))
    _add_heading(story, "Costs And Contributions", styles)
    expenses = report.expenses
    _add_key_value_table(
        story,
        [
            ["Total budget", _money(expenses.total_budget)],
            ["Total spent", _money(expenses.total_spent)],
            ["Remaining budget", _money(expenses.remaining_budget)],
            ["Over budget amount", _money(expenses.over_budget_amount)],
            ["Over budget", "Yes" if expenses.is_over_budget else "No"],
        ],
    )

    if expenses.category_breakdown:
        data = [["Category", "Total"]]
        data.extend(
            [item.category.title(), _money(item.total)]
            for item in expenses.category_breakdown
        )
        _add_table(story, data)

    if expenses.member_balances:
        balances = [["Member", "Paid", "Share", "Net"]]
        balances.extend(
            [
                balance.full_name,
                _money(balance.paid_total),
                _money(balance.share_total),
                _money(balance.net_balance),
            ]
            for balance in expenses.member_balances
        )
        _add_table(story, balances)


def _add_members(story: list, report: TripReportSummaryResponse, styles) -> None:
    _add_heading(story, "Trip Members", styles)
    data = [["Name", "Email", "Role", "Status"]]
    data.extend(
        [member.full_name, str(member.email), member.role, member.status]
        for member in report.members
    )
    _add_table(story, data)


def _add_key_value_table(story: list, data: list[list[str]]) -> None:
    _add_table(story, data, header=False)


def _add_table(story: list, data, *, header: bool = True) -> None:
    table = Table(data, hAlign="LEFT", repeatRows=1 if header else 0)
    table.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.25, colors.lightgrey),
                ("BACKGROUND", (0, 0), (-1, 0), colors.whitesmoke if header else colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold" if header else "Helvetica"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.extend([table, Spacer(1, 8)])


def _date_range(start_date, end_date) -> str:
    if start_date and end_date:
        return f"{start_date.isoformat()} to {end_date.isoformat()}"
    if start_date:
        return start_date.isoformat()
    if end_date:
        return f"Until {end_date.isoformat()}"
    return "Not set"


def _money(value) -> str:
    return f"PHP {value:.2f}"


def _pdf_text(value: str) -> str:
    return escape(value, quote=False)
