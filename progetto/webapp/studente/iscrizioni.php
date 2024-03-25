<?php
include '../scripts/db_connection.php';
session_start();

// Controlla se l'utente è loggato, altrimenti reindirizza alla pagina di login
if (!isset($_SESSION['email'])) {
    header("Location: /login.php");
    exit();

    print_r($_SESSION['id']);
}


?>

<!DOCTYPE html>
<html>
<head>
    <title>Iscrizioni</title>
    <link rel="stylesheet" type="text/css" href="./iscrizioni.css">
</head>
<body>
    <div class="sfondo">
        <div class="contenitore">
        <div class="logo">
                <a class="nav-link" id="uni" aria-current="page" href="/login.php">Universal</a>
                <br><br>
        </div>
        <br>
        <br>
        <div class="titolo"><h1>Iscrizioni confermate</h1></div>
        <div class="tabella">
            <table>
                <tr>
                    <th>Data</th>
                    <th>Luogo</th>
                    <th>Insegnamento</th>
                    <th>Azioni</th>
                </tr>
                <?php
                // Esegui la query per ottenere gli appelli degli esami a cui lo studente è attualmente iscritto
                $query_get_enrollements = "SELECT * FROM universal.get_student_exam_enrollments($1)";
                $result_get_enrollements = pg_query_params($conn, $query_get_enrollements, array($_SESSION['id']));

                // Itera sui risultati e stampa le righe della tabella
                while ($row_enrollements = pg_fetch_assoc($result_get_enrollements)) {
                    echo "<tr>";
                    echo "<td>" . $row_enrollements['data'] . "</td>";
                    echo "<td>" . $row_enrollements['luogo'] . "</td>";
                    echo "<td>" . $row_enrollements['nome_insegnamento'] . "</td>";
                    // Aggiungi qui il bottone per la disiscrizione
                    echo "<td><button onclick='unsubscribe(" . $row_enrollements['id_appuntamento'] . ")'>Disiscriviti</button></td>";
                    echo "</tr>";
                }
                ?>
            </table>

        </div>
                    

        </div>
        
    </div>

    <footer>
        <div>
            Università degli studi di Universal
        </div>
        <div>
            Made by Jack during the small hours
        </div>
        <div>
            <a href="https://letmegooglethat.com/?q=cerca+qui+i+tuoi+problemi%2C+grazie">Assistenza Universal</a>
            <br>
        </div>
    </footer>

    

</body>
</html>
